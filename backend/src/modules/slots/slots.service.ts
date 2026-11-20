import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import matchingConfig from "../../config/matching.config.ts";
import {
  EntitlementStatus,
  PaymentStatus,
} from "../../generated/prisma/client.ts";
import { expireSlotsAndDowngrade } from "./slots.expiry.ts";
import { getSlotPaymentProvider } from "./slots.payment.ts";

export const getActivationSummary = async (userId: string) => {
  // 1. Lazy expiration check
  await expireSlotsAndDowngrade(userId);

  const now = new Date();
  const threeDaysFromNow = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

  // 2. Fetch user's active pets and active slot entitlements
  const [activePets, entitlements, unreadMessages] = await Promise.all([
    prisma.pet.findMany({
      where: { userId, isActive: true },
      select: {
        id: true,
        name: true,
        animalType: true,
        breed: true,
        imageUrl: true,
        profilePictureUrl: true,
        activatedAt: true,
      },
      orderBy: [{ activatedAt: "asc" }, { createdAt: "asc" }],
    }),
    prisma.activeSlotEntitlement.findMany({
      where: {
        ownerId: userId,
        status: EntitlementStatus.ACTIVE,
        expiresAt: { gt: now },
      },
      orderBy: { expiresAt: "asc" },
      select: {
        id: true,
        startsAt: true,
        expiresAt: true,
        status: true,
      },
    }),
    prisma.userDowngradeMessage.findMany({
      where: { userId, read: false },
      orderBy: { createdAt: "desc" },
      take: 1,
    }),
  ]);

  const paidSlotsCount = entitlements.length;
  const allowedActive = matchingConfig.FREE_ACTIVE_PETS + paidSlotsCount;
  const activeCount = activePets.length;

  // Check if any slot is expiring within 3 days
  const expiringSoonSlot = entitlements.find(
    (e) => e.expiresAt > now && e.expiresAt <= threeDaysFromNow
  );

  const latestDowngradeMessage = unreadMessages[0]?.message || null;

  return {
    allowedActive,
    activeCount,
    freeSlots: matchingConfig.FREE_ACTIVE_PETS,
    paidSlotsCount,
    maxPaidSlots: matchingConfig.MAX_PAID_SLOTS,
    availableSlotsToPurchase: Math.max(
      0,
      matchingConfig.MAX_PAID_SLOTS - paidSlotsCount
    ),
    paidSlots: entitlements.map((e) => ({
      id: e.id,
      startsAt: e.startsAt,
      expiresAt: e.expiresAt,
      isExpiringSoon: e.expiresAt <= threeDaysFromNow,
    })),
    activePets,
    pricePerSlotNpr: matchingConfig.SLOT_PRICE_NPR,
    slotDurationDays: matchingConfig.SLOT_DURATION_DAYS,
    expiringSoonWarning: expiringSoonSlot
      ? `One of your active slots expires on ${expiringSoonSlot.expiresAt.toISOString().split("T")[0]}. Renew to prevent your pet from being deactivated!`
      : null,
    recentDowngradeMessage: latestDowngradeMessage,
  };
};

export const initiateSlotCheckout = async ({
  userId,
  quantity,
  gateway = "esewa",
}: {
  userId: string;
  quantity: number;
  gateway?: string;
}) => {
  if (!quantity || quantity <= 0) {
    throw new AppError("Quantity must be at least 1", 400);
  }

  // 1. Lazy expiration check
  await expireSlotsAndDowngrade(userId);

  const now = new Date();
  const currentPaidSlots = await prisma.activeSlotEntitlement.count({
    where: {
      ownerId: userId,
      status: EntitlementStatus.ACTIVE,
      expiresAt: { gt: now },
    },
  });

  if (currentPaidSlots + quantity > matchingConfig.MAX_PAID_SLOTS) {
    throw new AppError(
      `Cannot purchase ${quantity} slots. You currently hold ${currentPaidSlots} active slots and maximum allowed is ${matchingConfig.MAX_PAID_SLOTS}.`,
      400
    );
  }

  const unitPrice = matchingConfig.SLOT_PRICE_NPR;
  const totalAmount = unitPrice * quantity;

  // 2. Create PENDING Payment record in database
  const payment = await prisma.slotPayment.create({
    data: {
      userId,
      amount: totalAmount,
      quantity,
      gateway: gateway.toLowerCase(),
      status: PaymentStatus.PENDING,
    },
  });

  // 3. Initiate payment via Provider
  const provider = getSlotPaymentProvider(gateway);
  const initiation = await provider.initiatePayment({
    paymentId: payment.id,
    amount: totalAmount,
    userId,
    description: `Purchase of ${quantity} PetMate Active Slot(s)`,
  });

  // Store transactionId
  await prisma.slotPayment.update({
    where: { id: payment.id },
    data: { transactionId: initiation.transactionId },
  });

  return {
    paymentId: payment.id,
    amount: totalAmount,
    quantity,
    gateway: initiation.gateway,
    transactionId: initiation.transactionId,
    paymentUrl: initiation.paymentUrl,
    params: initiation.params,
  };
};

export const verifyAndGrantSlots = async ({
  paymentId,
  transactionId,
  gatewayPayload,
}: {
  paymentId: string;
  transactionId?: string;
  gatewayPayload?: any;
}) => {
  // 1. Fetch Payment record
  const payment = await prisma.slotPayment.findUnique({
    where: { id: paymentId },
    include: { entitlements: true },
  });

  if (!payment) {
    throw new AppError("Payment record not found", 404);
  }

  // Idempotency: if already completed, return existing entitlements
  if (payment.status === PaymentStatus.COMPLETED) {
    return {
      status: "COMPLETED",
      alreadyProcessed: true,
      entitlements: payment.entitlements,
      message: "Payment has already been verified and entitlements granted",
    };
  }

  // 2. Server-side verification with Gateway API
  const provider = getSlotPaymentProvider(payment.gateway);
  const verification = await provider.verifyPayment({
    paymentId,
    transactionId: transactionId || payment.transactionId || undefined,
    gatewayPayload,
  });

  if (!verification.success) {
    await prisma.slotPayment.update({
      where: { id: paymentId },
      data: { status: PaymentStatus.FAILED },
    });
    throw new AppError("Payment verification failed from payment gateway", 400);
  }

  // 3. Create Entitlements in ONE transaction
  const now = new Date();
  const expiresAt = new Date(
    Date.now() + matchingConfig.SLOT_DURATION_DAYS * 24 * 60 * 60 * 1000
  );

  return await prisma.$transaction(async (tx) => {
    // Update payment status to COMPLETED
    await tx.slotPayment.update({
      where: { id: paymentId },
      data: {
        status: PaymentStatus.COMPLETED,
        transactionId: verification.transactionId,
      },
    });

    // Create entitlements
    const createdEntitlements = [];
    for (let i = 0; i < payment.quantity; i++) {
      const ent = await tx.activeSlotEntitlement.create({
        data: {
          ownerId: payment.userId,
          paymentId: payment.id,
          startsAt: now,
          expiresAt,
          status: EntitlementStatus.ACTIVE,
        },
      });
      createdEntitlements.push(ent);
    }

    return {
      status: "COMPLETED",
      alreadyProcessed: false,
      entitlements: createdEntitlements,
      message: `Successfully granted ${payment.quantity} active pet slot(s) valid for ${matchingConfig.SLOT_DURATION_DAYS} days`,
    };
  });
};

export const revokeEntitlement = async ({
  adminUserId,
  entitlementId,
  reason,
}: {
  adminUserId: string;
  entitlementId: string;
  reason?: string;
}) => {
  const entitlement = await prisma.activeSlotEntitlement.findUnique({
    where: { id: entitlementId },
  });

  if (!entitlement) {
    throw new AppError("Slot entitlement not found", 404);
  }

  return await prisma.$transaction(async (tx) => {
    const updated = await tx.activeSlotEntitlement.update({
      where: { id: entitlementId },
      data: { status: EntitlementStatus.REVOKED },
    });

    // Record admin audit log
    await tx.adminAuditLog.create({
      data: {
        actorId: adminUserId,
        targetId: entitlement.ownerId,
        action: "REVOKE_SLOT_ENTITLEMENT",
        oldValue: entitlement.status,
        newValue: `REVOKED (${reason || "No reason provided"})`,
      },
    });

    return updated;
  });
};

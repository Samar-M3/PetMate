import prisma from "../../config/db.ts";
import { EntitlementStatus } from "../../generated/prisma/client.ts";
import matchingConfig from "../../config/matching.config.ts";

/**
 * Checks for expired entitlements globally or for a specific user.
 * Deactivates extra pets keeping the earliest-activated ones, and records a downgrade message.
 */
export async function expireSlotsAndDowngrade(userId?: string): Promise<{
  expiredCount: number;
  downgradedOwners: number;
}> {
  const now = new Date();

  // 1. Expire entitlements that passed expiresAt
  const expiredResult = await prisma.activeSlotEntitlement.updateMany({
    where: {
      status: EntitlementStatus.ACTIVE,
      expiresAt: { lt: now },
      ...(userId ? { ownerId: userId } : {}),
    },
    data: {
      status: EntitlementStatus.EXPIRED,
    },
  });

  // 2. Identify owners who have active pets exceeding allowedActive
  const candidateUserWhere = userId ? { id: userId } : {};
  const usersWithActivePets = await prisma.user.findMany({
    where: candidateUserWhere,
    select: {
      id: true,
      pets: {
        where: { isActive: true },
        orderBy: [{ activatedAt: "asc" }, { createdAt: "asc" }],
        select: { id: true, name: true, activatedAt: true },
      },
      slotEntitlements: {
        where: {
          status: EntitlementStatus.ACTIVE,
          expiresAt: { gt: now },
        },
        select: { id: true },
      },
    },
  });

  let downgradedOwners = 0;

  for (const user of usersWithActivePets) {
    const activeCount = user.pets.length;
    const paidSlots = user.slotEntitlements.length;
    const allowedActive = matchingConfig.FREE_ACTIVE_PETS + paidSlots;

    if (activeCount > allowedActive) {
      // Keep earliest-activated pets up to allowedActive
      const petsToKeep = user.pets.slice(0, allowedActive);
      const petsToDeactivate = user.pets.slice(allowedActive);
      const petIdsToDeactivate = petsToDeactivate.map((p) => p.id);

      await prisma.$transaction(async (tx) => {
        await tx.pet.updateMany({
          where: { id: { in: petIdsToDeactivate } },
          data: { isActive: false },
        });

        const deactivatedNames = petsToDeactivate.map((p) => p.name).join(", ");
        const message = `Your paid slot has expired. The following pet profile(s) have been automatically deactivated: ${deactivatedNames}.`;

        await tx.userDowngradeMessage.create({
          data: {
            userId: user.id,
            message,
          },
        });
      });

      downgradedOwners++;
    }
  }

  return {
    expiredCount: expiredResult.count,
    downgradedOwners,
  };
}

let slotSchedulerTimer: NodeJS.Timeout | null = null;

/**
 * Background hourly task to expire slots and downgrade pets.
 */
export function startSlotExpiryScheduler(intervalMs = 60 * 60 * 1000): void {
  if (slotSchedulerTimer) return;
  expireSlotsAndDowngrade().catch((err) => {
    console.error("[SlotExpiryScheduler] Initial run error:", err);
  });

  slotSchedulerTimer = setInterval(() => {
    expireSlotsAndDowngrade().catch((err) => {
      console.error("[SlotExpiryScheduler] Interval error:", err);
    });
  }, intervalMs);

  if (slotSchedulerTimer.unref) {
    slotSchedulerTimer.unref();
  }
}

export function stopSlotExpiryScheduler(): void {
  if (slotSchedulerTimer) {
    clearInterval(slotSchedulerTimer);
    slotSchedulerTimer = null;
  }
}

import prisma from "../../config/db.ts";
import { firebaseAuth } from "../../config/firebase.ts";
import {
  Role,
  StoreStatus,
  ApplicationType,
  ApplicationStatus,
} from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { RegisterSellerInput } from "./sellers.validation.ts";

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export const registerSeller = async (input: RegisterSellerInput) => {
  // 1. Check if email exists in PostgreSQL
  const existingUserByEmail = await prisma.user.findFirst({
    where: { email: { equals: input.email, mode: "insensitive" } },
  });
  if (existingUserByEmail) {
    throw new AppError("An account with this email already exists", 409);
  }

  // 2. Check if store name or slug exists
  const baseSlug = slugify(input.storeName);
  const existingStore = await prisma.store.findFirst({
    where: {
      OR: [
        { name: { equals: input.storeName, mode: "insensitive" } },
        { slug: baseSlug },
      ],
    },
  });
  if (existingStore) {
    throw new AppError(
      "A store with this name already exists. Please choose a different store name.",
      409
    );
  }

  // 3. Create Firebase Auth user
  let firebaseUser;
  try {
    firebaseUser = await firebaseAuth.createUser({
      email: input.email,
      password: input.password,
      displayName: input.fullName,
    });
  } catch (err: any) {
    if (err.code === "auth/email-already-exists") {
      throw new AppError("An account with this email already exists in authentication system", 409);
    }
    throw new AppError(`Authentication setup failed: ${err.message}`, 400);
  }

  // 4. Generate verification link
  let verificationLink: string | null = null;
  try {
    verificationLink = await firebaseAuth.generateEmailVerificationLink(input.email);
  } catch (err) {
    // Non-fatal if email verification link generation fails in development
    console.warn("[SellersService] Notice: could not generate verification link:", err);
  }

  // 5. Create Database Records in Transaction
  try {
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          firebaseUid: firebaseUser.uid,
          email: input.email,
          phoneNumber: input.phoneNumber,
          role: Role.SELLER,
          isActive: true,
          onboardingCompleted: true,
          profile: {
            create: {
              fullName: input.fullName,
              location: `${input.city}, ${input.province}`,
              area: input.city,
            },
          },
        },
        include: { profile: true },
      });

      const store = await tx.store.create({
        data: {
          userId: user.id,
          name: input.storeName,
          slug: baseSlug,
          description: input.description,
          status: StoreStatus.PENDING,
          businessType: input.businessType || "INDIVIDUAL",
          businessAddress: input.businessAddress,
          city: input.city,
          province: input.province,
          postalCode: input.postalCode,
          registrationDocUrl: input.registrationDocUrl,
          identityDocUrl: input.identityDocUrl,
          submittedAt: new Date(),
        },
      });

      const application = await tx.roleApplication.create({
        data: {
          userId: user.id,
          type: ApplicationType.SELLER,
          status: ApplicationStatus.PENDING,
          notes: `Store: ${input.storeName} (${input.businessType || "INDIVIDUAL"}), ${input.city}, ${input.province}`,
        },
      });

      return { user, store, application };
    });

    return {
      message: "Seller registered successfully. Application is currently pending admin review.",
      user: {
        id: result.user.id,
        email: result.user.email,
        fullName: input.fullName,
        role: result.user.role,
      },
      store: {
        id: result.store.id,
        name: result.store.name,
        slug: result.store.slug,
        status: result.store.status,
        businessType: result.store.businessType,
        businessAddress: result.store.businessAddress,
        city: result.store.city,
        province: result.store.province,
        submittedAt: result.store.submittedAt,
      },
      verificationLink,
    };
  } catch (dbError: any) {
    // Rollback Firebase user if DB transaction fails
    try {
      await firebaseAuth.deleteUser(firebaseUser.uid);
    } catch (_) {}
    throw dbError;
  }
};

export const getSellerStatusByUserId = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
    include: {
      owner: {
        select: {
          id: true,
          email: true,
          phoneNumber: true,
          role: true,
          isActive: true,
          profile: { select: { fullName: true } },
        },
      },
    },
  });

  if (!store) {
    // Check if user has a pending role application
    const application = await prisma.roleApplication.findFirst({
      where: { userId, type: ApplicationType.SELLER },
      orderBy: { createdAt: "desc" },
    });

    return {
      hasStore: false,
      applicationStatus: application?.status || "NOT_APPLIED",
      notes: application?.notes,
      store: null,
    };
  }

  return {
    hasStore: true,
    applicationStatus: store.status,
    sellerName: store.owner.profile?.fullName ?? "Seller",
    email: store.owner.email,
    phoneNumber: store.owner.phoneNumber,
    isActive: store.owner.isActive,
    store: {
      id: store.id,
      name: store.name,
      slug: store.slug,
      status: store.status,
      businessType: store.businessType,
      businessAddress: store.businessAddress,
      city: store.city,
      province: store.province,
      postalCode: store.postalCode,
      description: store.description,
      registrationDocUrl: store.registrationDocUrl,
      identityDocUrl: store.identityDocUrl,
      rejectionReason: store.rejectionReason,
      submittedAt: store.submittedAt,
      reviewedAt: store.reviewedAt,
    },
  };
};

export const resubmitSellerApplication = async (
  userId: string,
  data: Partial<RegisterSellerInput>
) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("No seller store found for this account", 404);
  }

  if (store.status === StoreStatus.APPROVED) {
    throw new AppError("This seller application is already approved", 400);
  }

  const updatedStore = await prisma.$transaction(async (tx) => {
    const s = await tx.store.update({
      where: { userId },
      data: {
        name: data.storeName || store.name,
        slug: data.storeName ? slugify(data.storeName) : store.slug,
        description: data.description !== undefined ? data.description : store.description,
        businessType: data.businessType || store.businessType,
        businessAddress: data.businessAddress || store.businessAddress,
        city: data.city || store.city,
        province: data.province || store.province,
        postalCode: data.postalCode || store.postalCode,
        registrationDocUrl: data.registrationDocUrl !== undefined ? data.registrationDocUrl : store.registrationDocUrl,
        identityDocUrl: data.identityDocUrl !== undefined ? data.identityDocUrl : store.identityDocUrl,
        status: StoreStatus.PENDING,
        rejectionReason: null,
        submittedAt: new Date(),
      },
    });

    // Reset role application
    const app = await tx.roleApplication.findFirst({
      where: { userId, type: ApplicationType.SELLER },
      orderBy: { createdAt: "desc" },
    });

    if (app) {
      await tx.roleApplication.update({
        where: { id: app.id },
        data: {
          status: ApplicationStatus.PENDING,
          notes: `Resubmitted: ${s.name} (${s.businessType}), ${s.city}, ${s.province}`,
          reviewedAt: null,
          reviewedBy: null,
        },
      });
    } else {
      await tx.roleApplication.create({
        data: {
          userId,
          type: ApplicationType.SELLER,
          status: ApplicationStatus.PENDING,
          notes: `Resubmitted: ${s.name} (${s.businessType}), ${s.city}, ${s.province}`,
        },
      });
    }

    return s;
  });

  return updatedStore;
};

export const forgotPassword = async (email: string) => {
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    throw new AppError("Please provide a valid email address", 400);
  }

  try {
    const link = await firebaseAuth.generatePasswordResetLink(email.trim().toLowerCase());
    // In production this would dispatch an email; returning link in response or console for easy dev testing
    console.log(`[SellersService] 🔑 Password reset link generated for ${email}: ${link}`);
  } catch (err: any) {
    // For security, never leak whether the email exists
    console.warn(`[SellersService] Password reset requested for unknown or invalid email: ${email}`);
  }

  return {
    message: "If an account is associated with this email, a password reset link has been sent.",
  };
};

export const getSellerDashboardStats = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
    include: {
      products: {
        select: { id: true, name: true, status: true, availableStock: true, basePrice: true },
      },
    },
  });

  if (!store) {
    throw new AppError("Store not found", 404);
  }

  if (store.status !== StoreStatus.APPROVED) {
    throw new AppError("Seller account is not approved yet", 403);
  }

  return {
    store: {
      id: store.id,
      name: store.name,
      slug: store.slug,
      status: store.status,
      businessType: store.businessType,
      city: store.city,
      province: store.province,
    },
    totalProducts: store.products.length,
    activeProducts: store.products.filter((p) => p.status === "ACTIVE").length,
    outOfStockProducts: store.products.filter((p) => p.status === "OUT_OF_STOCK" || p.availableStock <= 0).length,
    products: store.products.slice(0, 5),
  };
};

import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const initializeUserRecord = async (
  firebaseUid: string,
  email?: string,
  phoneNumber?: string
) => {
  const user = await prisma.user.upsert({
    where: { firebaseUid },
    update: {
      email: email || undefined,
      phoneNumber: phoneNumber || undefined,
    },
    create: {
      firebaseUid,
      email: email || null,
      phoneNumber: phoneNumber || null,
      onboardingCompleted: false,
    },
    include: {
      profile: true,
      pets: true,
    },
  });

  return user;
};

export const getUserDetails = async (userId: string) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
      pets: {
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!user) {
    throw new AppError("User not found", 404);
  }

  return user;
};

export interface UpdateOwnerProfileDTO {
  fullName?: string;
  profilePictureUrl?: string;
  location?: string;
  area?: string;
  bio?: string;
  phoneNumber?: string;
  onboardingCompleted?: boolean;
}

export const updateOwnerProfile = async (
  userId: string,
  data: UpdateOwnerProfileDTO
) => {
  return await prisma.$transaction(async (tx) => {
    // 1. Update phone number or onboarding status on User
    const updatedUser = await tx.user.update({
      where: { id: userId },
      data: {
        phoneNumber: data.phoneNumber || undefined,
        onboardingCompleted:
          typeof data.onboardingCompleted === "boolean"
            ? data.onboardingCompleted
            : true,
      },
    });

    // 2. Upsert Profile
    const profile = await tx.profile.upsert({
      where: { userId },
      update: {
        fullName: data.fullName ?? undefined,
        profilePictureUrl: data.profilePictureUrl ?? undefined,
        location: data.location ?? undefined,
        area: data.area ?? undefined,
        bio: data.bio ?? undefined,
      },
      create: {
        userId,
        fullName: data.fullName ?? null,
        profilePictureUrl: data.profilePictureUrl ?? null,
        location: data.location ?? null,
        area: data.area ?? null,
        bio: data.bio ?? null,
      },
    });

    return {
      ...updatedUser,
      profile,
    };
  });
};

export const getOnboardingStatus = async (firebaseUid: string) => {
  const user = await prisma.user.findUnique({
    where: { firebaseUid },
    include: {
      profile: true,
      pets: {
        select: { id: true },
      },
    },
  });

  if (!user) {
    return {
      isInitialized: false,
      onboardingCompleted: false,
      hasPets: false,
      hasProfile: false,
      nextStep: "INITIALIZE",
    };
  }

  const hasPets = user.pets.length > 0;
  const hasProfile = Boolean(user.profile && user.profile.fullName && user.profile.location);

  let nextStep: "INITIALIZE" | "PET_INFO" | "OWNER_INFO" | "COMPLETED" = "COMPLETED";
  if (!user.onboardingCompleted) {
    if (!hasPets) {
      nextStep = "PET_INFO";
    } else if (!hasProfile) {
      nextStep = "OWNER_INFO";
    } else {
      nextStep = "COMPLETED";
    }
  }

  return {
    isInitialized: true,
    userId: user.id,
    onboardingCompleted: user.onboardingCompleted,
    hasPets,
    hasProfile,
    nextStep,
  };
};

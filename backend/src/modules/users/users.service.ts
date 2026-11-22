import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { uploadImage, deleteImage } from "../../services/image.service.ts";

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
        include: { images: true },
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
  imageUrl?: string;
  imagePublicId?: string;
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
  const resolvedImageUrl = data.imageUrl || data.profilePictureUrl;

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
        profilePictureUrl: resolvedImageUrl ?? undefined,
        imageUrl: resolvedImageUrl ?? undefined,
        imagePublicId: data.imagePublicId ?? undefined,
        location: data.location ?? undefined,
        area: data.area ?? undefined,
        bio: data.bio ?? undefined,
      },
      create: {
        userId,
        fullName: data.fullName ?? null,
        profilePictureUrl: resolvedImageUrl ?? null,
        imageUrl: resolvedImageUrl ?? null,
        imagePublicId: data.imagePublicId ?? null,
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

/**
 * Uploads user avatar to Cloudinary, updates DB, cleans up old image,
 * and ensures no orphan image remains on DB failure.
 */
export const updateUserAvatar = async (userId: string, fileBuffer: Buffer) => {
  // 1. Check existing profile for previous publicId
  const existingProfile = await prisma.profile.findUnique({
    where: { userId },
  });

  const oldPublicId = existingProfile?.imagePublicId;

  // 2. Upload to Cloudinary with fixed publicId for avatars to allow overwrite
  const avatarPublicId = `avatar_${userId}`;
  const uploaded = await uploadImage(fileBuffer, "users", avatarPublicId);

  // 3. Update database
  try {
    const updatedProfile = await prisma.profile.upsert({
      where: { userId },
      update: {
        imageUrl: uploaded.imageUrl,
        profilePictureUrl: uploaded.imageUrl,
        imagePublicId: uploaded.imagePublicId,
      },
      create: {
        userId,
        imageUrl: uploaded.imageUrl,
        profilePictureUrl: uploaded.imageUrl,
        imagePublicId: uploaded.imagePublicId,
      },
    });

    // 4. Delete old image if publicId changed
    if (oldPublicId && oldPublicId !== uploaded.imagePublicId) {
      await deleteImage(oldPublicId);
    }

    return {
      imageUrl: updatedProfile.imageUrl!,
      imagePublicId: updatedProfile.imagePublicId!,
      profile: updatedProfile,
    };
  } catch (error) {
    // If DB update fails, clean up the newly uploaded image immediately
    await deleteImage(uploaded.imagePublicId);
    throw error;
  }
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
  const hasProfile = Boolean(
    user.profile &&
      user.profile.fullName &&
      user.profile.location &&
      (user.profile.imageUrl || user.profile.profilePictureUrl)
  );

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

export const submitRoleApplication = async (
  userId: string,
  type: "SELLER" | "VETERINARIAN",
  notes?: string
) => {
  if (type !== "SELLER" && type !== "VETERINARIAN") {
    throw new AppError("Invalid application type. Must be SELLER or VETERINARIAN", 400);
  }

  const existing = await prisma.roleApplication.findFirst({
    where: { userId, type, status: "PENDING" },
  });

  if (existing) {
    throw new AppError(
      `You already have a pending application for ${type}`,
      409
    );
  }

  return prisma.roleApplication.create({
    data: {
      userId,
      type,
      notes,
    },
  });
};

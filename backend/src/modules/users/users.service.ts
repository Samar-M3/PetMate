import prisma from "../../config/db.ts";
import bcrypt from "bcryptjs";
import { firebaseAuth } from "../../config/firebase.ts";
import { MatchStatus, Role } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { uploadImage, deleteImage } from "../../services/image.service.ts";
import { checkPetProfileCompleteness } from "../pets/pets.service.ts";
import { calculateAgeInMonths, calculateAgeString } from "../matching/matching.service.ts";
import { endConversation } from "../../services/firestore.service.ts";

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

export const completeInitialVeterinarianPassword = async (
  firebaseUid: string,
  newPassword: string,
) => {
  const user = await prisma.user.findUnique({
    where: { firebaseUid },
    include: { passwordSetup: true },
  });

  if (!user) throw new AppError("User not found", 404);
  if (user.role !== Role.VETERINARIAN) {
    throw new AppError("Only veterinarian accounts can use first-login password setup", 403);
  }
  if (!user.mustChangePassword) return getUserDetails(user.id);
  if (!user.passwordSetup) {
    throw new AppError("Temporary password setup record is missing; contact an administrator", 409);
  }

  if (await bcrypt.compare(newPassword, user.passwordSetup.temporaryPasswordHash)) {
    throw new AppError("Choose a password different from the temporary password", 400);
  }

  try {
    await firebaseAuth.updateUser(firebaseUid, { password: newPassword });
  } catch (error: any) {
    if (error?.code === "auth/user-not-found") {
      throw new AppError("Authentication account was not found", 404);
    }
    if (error?.code === "auth/invalid-password") {
      throw new AppError("New password does not meet Firebase requirements", 400);
    }
    throw new AppError("Could not update the authentication password", 502);
  }

  await prisma.$transaction(async (tx) => {
    const updated = await tx.user.updateMany({
      where: { id: user.id, mustChangePassword: true },
      data: { mustChangePassword: false },
    });
    if (updated.count !== 1) {
      throw new AppError("First-login password setup has already been completed", 409);
    }

    await tx.veterinarianPasswordSetup.deleteMany({ where: { userId: user.id } });
  });

  return getUserDetails(user.id);
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

  await prisma.$transaction(async (tx) => {
    // 1. Update phone number or onboarding status on User
    await tx.user.update({
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
    await tx.profile.upsert({
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
  });

  return await getUserDetails(userId);
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
    onboardingStep: user.profile?.onboardingStep ?? 1,
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

export const getPublicUserProfile = async (_callerUserId: string, targetUserId: string) => {
  if (!targetUserId || typeof targetUserId !== "string" || targetUserId.trim().length === 0) {
    throw new AppError("User is not available", 404);
  }

  const trimmedId = targetUserId.trim();

  // If caller and target have a block between them, return 404
  if (_callerUserId && _callerUserId !== trimmedId) {
    const block = await prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: _callerUserId, blockedId: trimmedId },
          { blockerId: trimmedId, blockedId: _callerUserId },
        ],
      },
    });
    if (block) {
      throw new AppError("User is not available", 404);
    }
  }

  const user = await prisma.user.findUnique({
    where: { id: trimmedId },
    include: {
      profile: true,
      pets: {
        where: { isActive: true },
        include: { images: { orderBy: { createdAt: "asc" } } },
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!user || !user.isActive) {
    throw new AppError("User is not available", 404);
  }

  // Filter only complete active pets
  const activeAndCompletePets = user.pets.filter((p) => {
    const missing = checkPetProfileCompleteness({
      name: p.name,
      animalType: p.animalType,
      breed: p.breed,
      gender: p.gender,
      dateOfBirth: p.dateOfBirth,
      imageUrl: p.imageUrl,
      profilePictureUrl: p.profilePictureUrl,
      images: p.images,
    });
    return missing.length === 0;
  });

  const profile = user.profile;
  const displayName = profile?.fullName || profile?.username || "Pet Parent";
  const avatarUrl = profile?.profilePictureUrl || profile?.imageUrl || null;

  const monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  const memberSince = `${monthNames[user.createdAt.getMonth()]} ${user.createdAt.getFullYear()}`;

  const petCards = activeAndCompletePets.map((p) => {
    const photoUrl = p.imageUrl || p.profilePictureUrl || p.images[0]?.imageUrl || "";
    return {
      id: p.id,
      name: p.name,
      species: p.animalType || "Pet",
      breed: p.breed || "Mixed",
      ageMonths: calculateAgeInMonths(p.dateOfBirth),
      ageString: calculateAgeString(p.dateOfBirth),
      photoUrl,
    };
  });

  // Explicit allowlist payload (never return private fields)
  return {
    id: user.id,
    displayName,
    avatarUrl,
    memberSince,
    area: profile?.area || profile?.location || null,
    bio: profile?.bio || null,
    pets: petCards,
  };
};

export const blockUser = async (blockerId: string, blockedId: string) => {
  if (blockerId === blockedId) {
    throw new AppError("You cannot block yourself", 400);
  }

  const blockedUser = await prisma.user.findUnique({
    where: { id: blockedId },
  });
  if (!blockedUser) {
    throw new AppError("User not found", 404);
  }

  await prisma.userBlock.upsert({
    where: {
      blockerId_blockedId: { blockerId, blockedId },
    },
    update: {},
    create: {
      blockerId,
      blockedId,
    },
  });

  // End all active matches between blocker's pets and blocked user's pets
  const blockerPets = await prisma.pet.findMany({
    where: { userId: blockerId },
    select: { id: true },
  });
  const blockedPets = await prisma.pet.findMany({
    where: { userId: blockedId },
    select: { id: true },
  });

  const blockerPetIds = blockerPets.map((p) => p.id);
  const blockedPetIds = blockedPets.map((p) => p.id);

  if (blockerPetIds.length > 0 && blockedPetIds.length > 0) {
    const activeMatches = await prisma.match.findMany({
      where: {
        status: MatchStatus.ACTIVE,
        OR: [
          { petAId: { in: blockerPetIds }, petBId: { in: blockedPetIds } },
          { petAId: { in: blockedPetIds }, petBId: { in: blockerPetIds } },
        ],
      },
      select: { id: true },
    });

    if (activeMatches.length > 0) {
      await prisma.match.updateMany({
        where: { id: { in: activeMatches.map((m) => m.id) } },
        data: {
          status: MatchStatus.ENDED,
          endedAt: new Date(),
          endedBy: blockerId,
        },
      });

      for (const m of activeMatches) {
        await endConversation(m.id, "BLOCKED");
      }
    }
  }

  return { success: true, blockedUserId: blockedId };
};

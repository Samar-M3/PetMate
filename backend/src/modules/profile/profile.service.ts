import prisma from "../../config/db.ts";
import { PetProfileStatus } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { UpdateProfileMeInput } from "./profile.validation.ts";

export const getOwnerProfile = async (userId: string) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
      pets: {
        orderBy: { createdAt: "desc" },
        include: {
          images: { orderBy: [{ position: "asc" }, { createdAt: "asc" }] },
        },
      },
    },
  });

  if (!user) {
    throw new AppError("User not found", 404);
  }

  let profile = user.profile;
  if (!profile) {
    profile = await prisma.profile.create({
      data: {
        userId: user.id,
        onboardingStep: 1,
        onboardingCompleted: user.onboardingCompleted,
      },
    });
  }

  // Sync onboardingCompleted if user flag is already true
  const onboardingCompleted = Boolean(
    user.onboardingCompleted || profile.onboardingCompleted
  );

  // Return safe owner profile + active/draft pet for onboarding resume
  const draftPet =
    user.pets.find((p) => p.profileStatus === PetProfileStatus.DRAFT) ||
    user.pets[0] ||
    null;

  return {
    id: profile.id,
    userId: user.id,
    email: user.email,
    role: user.role,
    displayName: profile.fullName || "",
    avatarUrl: profile.profilePictureUrl || profile.imageUrl || null,
    city: profile.city || profile.location || "",
    district: profile.district || profile.area || "",
    onboardingStep: onboardingCompleted ? 4 : profile.onboardingStep,
    onboardingCompleted,
    registrationCompleted: Boolean(
      user.registrationCompleted || profile.registrationCompleted || onboardingCompleted
    ),
    draftPet,
    petsCount: user.pets.length,
  };
};

export const updateOwnerProfileStep1 = async (
  userId: string,
  input: UpdateProfileMeInput
) => {
  const existing = await prisma.profile.findUnique({ where: { userId } });
  const nextStep = Math.max(existing?.onboardingStep ?? 1, 2);

  if (input.phoneNumber) {
    await prisma.user.update({
      where: { id: userId },
      data: { phoneNumber: input.phoneNumber },
    });
  }

  const profile = await prisma.profile.upsert({
    where: { userId },
    update: {
      fullName: input.displayName,
      displayName: input.displayName,
      ...(input.phoneNumber ? { phone: input.phoneNumber } : {}),
      ...(input.termsAccepted ? { termsAcceptedAt: new Date() } : {}),
      ...(input.avatarUrl !== undefined
        ? {
            avatarUrl: input.avatarUrl,
            profilePictureUrl: input.avatarUrl,
            imageUrl: input.avatarUrl,
            imagePublicId: input.avatarPublicId ?? undefined,
          }
        : {}),
      city: input.city,
      district: input.district,
      location: input.city,
      area: input.district,
      onboardingStep: nextStep,
    },
    create: {
      userId,
      fullName: input.displayName,
      displayName: input.displayName,
      phone: input.phoneNumber ?? null,
      termsAcceptedAt: input.termsAccepted ? new Date() : null,
      avatarUrl: input.avatarUrl ?? null,
      profilePictureUrl: input.avatarUrl ?? null,
      imageUrl: input.avatarUrl ?? null,
      imagePublicId: input.avatarPublicId ?? null,
      city: input.city,
      district: input.district,
      location: input.city,
      area: input.district,
      onboardingStep: 2,
      onboardingCompleted: false,
    },
  });

  return {
    id: profile.id,
    userId: profile.userId,
    displayName: profile.fullName || "",
    avatarUrl: profile.profilePictureUrl || profile.imageUrl || null,
    city: profile.city || "",
    district: profile.district || "",
    onboardingStep: profile.onboardingStep,
    onboardingCompleted: profile.onboardingCompleted,
  };
};

export const completeOwnerOnboarding = async (userId: string, petId?: string) => {
  return await prisma.$transaction(async (tx) => {
    const user = await tx.user.findUnique({
      where: { id: userId },
      include: { pets: { orderBy: { createdAt: "desc" } } },
    });

    if (!user) {
      throw new AppError("User not found", 404);
    }

    // Find target pet (explicit petId, or latest DRAFT pet, or latest pet)
    const targetPet = petId
      ? user.pets.find((p) => p.id === petId)
      : user.pets.find((p) => p.profileStatus === PetProfileStatus.DRAFT) ||
        user.pets[0];

    if (!targetPet) {
      throw new AppError(
        "Please create a pet profile before completing setup.",
        400
      );
    }

    const hasActivePet = user.pets.some((p) => p.isActive);

    const completedPet = await tx.pet.update({
      where: { id: targetPet.id },
      data: {
        profileStatus: PetProfileStatus.COMPLETE,
        isActive: hasActivePet ? targetPet.isActive : true,
        activatedAt: hasActivePet ? targetPet.activatedAt : new Date(),
      },
      include: {
        images: { orderBy: [{ position: "asc" }, { createdAt: "asc" }] },
      },
    });

    await tx.user.update({
      where: { id: userId },
      data: {
        onboardingCompleted: true,
        registrationCompleted: true,
      },
    });

    const profile = await tx.profile.upsert({
      where: { userId },
      update: {
        onboardingCompleted: true,
        registrationCompleted: true,
        onboardingStep: 4,
      },
      create: {
        userId,
        onboardingCompleted: true,
        registrationCompleted: true,
        onboardingStep: 4,
      },
    });

    return {
      onboardingCompleted: true,
      registrationCompleted: true,
      onboardingStep: profile.onboardingStep,
      pet: completedPet,
    };
  });
};

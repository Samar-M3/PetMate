import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { uploadImage, deleteImage } from "../../services/image.service.ts";
import matchingConfig from "../../config/matching.config.ts";
import { RequestStatus, MatchStatus, EntitlementStatus } from "../../generated/prisma/client.ts";

export interface CreatePetDTO {
  name: string;
  profilePictureUrl?: string;
  imageUrl?: string;
  imagePublicId?: string;
  animalType: string;
  breed: string;
  gender: string;
  dateOfBirth?: string | Date;
  color?: string;
  personality?: string[];
  vaccinationStatus: string;
  allergies?: string;
  description?: string;
}

export interface UpdatePetDTO {
  name?: string;
  profilePictureUrl?: string;
  imageUrl?: string;
  imagePublicId?: string;
  animalType?: string;
  breed?: string;
  gender?: string;
  dateOfBirth?: string | Date;
  color?: string;
  personality?: string[];
  vaccinationStatus?: string;
  allergies?: string;
  description?: string;
}

/**
 * Validates whether a pet's profile is complete:
 * (name, species, breed, sex, birth date, at least one photo).
 * Returns array of missing field names.
 */
export function checkPetProfileCompleteness(pet: {
  name?: string | null;
  animalType?: string | null;
  breed?: string | null;
  gender?: string | null;
  dateOfBirth?: Date | null;
  imageUrl?: string | null;
  profilePictureUrl?: string | null;
  images?: Array<{ imageUrl?: string | null }> | null;
}): string[] {
  const missing: string[] = [];
  if (!pet.name || pet.name.trim() === "") missing.push("name");
  if (!pet.animalType || pet.animalType.trim() === "") missing.push("species (animalType)");
  if (!pet.breed || pet.breed.trim() === "") missing.push("breed");
  if (!pet.gender || pet.gender.trim() === "") missing.push("sex (gender)");
  if (!pet.dateOfBirth) missing.push("birth date (dateOfBirth)");

  const hasPhoto = Boolean(
    (pet.imageUrl && pet.imageUrl.trim() !== "") ||
    (pet.profilePictureUrl && pet.profilePictureUrl.trim() !== "") ||
    (pet.images && pet.images.some((img) => img.imageUrl && img.imageUrl.trim() !== ""))
  );
  if (!hasPhoto) missing.push("at least one photo");

  return missing;
}

export const createPetForUser = async (userId: string, data: CreatePetDTO) => {
  if (!data.name || data.name.trim().length === 0) {
    throw new AppError("Pet name is required", 400);
  }
  if (!data.animalType || data.animalType.trim().length === 0) {
    throw new AppError("Animal type is required", 400);
  }
  if (!data.breed || data.breed.trim().length === 0) {
    throw new AppError("Breed is required", 400);
  }
  if (!data.gender || data.gender.trim().length === 0) {
    throw new AppError("Gender is required", 400);
  }
  if (!data.vaccinationStatus || data.vaccinationStatus.trim().length === 0) {
    throw new AppError("Vaccination status is required", 400);
  }

  const parsedDate = data.dateOfBirth ? new Date(data.dateOfBirth) : null;
  const resolvedImageUrl = data.imageUrl || data.profilePictureUrl || null;

  return await prisma.$transaction(async (tx) => {
    // 1. Enforce MAX_PETS_PER_OWNER inside transaction
    const existingCount = await tx.pet.count({
      where: { userId },
    });
    if (existingCount >= matchingConfig.MAX_PETS_PER_OWNER) {
      throw new AppError(
        `Owner cannot exceed maximum of ${matchingConfig.MAX_PETS_PER_OWNER} pets`,
        400
      );
    }

    // 2. Check if owner already has any active pet
    const activePetCount = await tx.pet.count({
      where: { userId, isActive: true },
    });

    // 3. Check completeness of new pet
    const missingFields = checkPetProfileCompleteness({
      name: data.name,
      animalType: data.animalType,
      breed: data.breed,
      gender: data.gender,
      dateOfBirth: parsedDate,
      imageUrl: resolvedImageUrl,
      profilePictureUrl: resolvedImageUrl,
      images: resolvedImageUrl ? [{ imageUrl: resolvedImageUrl }] : [],
    });

    // A new pet starts OFF, except the owner's first complete pet, which starts ON if the owner has no active pet
    const isComplete = missingFields.length === 0;
    const shouldStartActive = isComplete && activePetCount === 0;

    const pet = await tx.pet.create({
      data: {
        userId,
        name: data.name.trim(),
        profilePictureUrl: resolvedImageUrl,
        imageUrl: resolvedImageUrl,
        imagePublicId: data.imagePublicId || null,
        animalType: data.animalType.trim(),
        breed: data.breed.trim(),
        gender: data.gender.trim(),
        dateOfBirth: parsedDate,
        color: data.color?.trim() || null,
        personality: Array.isArray(data.personality) ? data.personality : [],
        vaccinationStatus: data.vaccinationStatus.trim(),
        allergies: data.allergies?.trim() || null,
        description: data.description?.trim() || null,
        isActive: shouldStartActive,
        activatedAt: shouldStartActive ? new Date() : null,
        images:
          resolvedImageUrl && data.imagePublicId
            ? {
                create: {
                  imageUrl: resolvedImageUrl,
                  imagePublicId: data.imagePublicId,
                  isMain: true,
                },
              }
            : undefined,
      },
      include: {
        images: true,
      },
    });

    return pet;
  });
};

export const getPetsForUser = async (userId: string) => {
  return await prisma.pet.findMany({
    where: { userId },
    orderBy: [{ isActive: "desc" }, { createdAt: "desc" }],
    include: { images: true },
  });
};

export const getPetById = async (userId: string, petId: string, isAdmin = false) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const pet = await prisma.pet.findFirst({
    where: whereClause,
    include: { images: true },
  });

  if (!pet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  return pet;
};

export const updatePetForUser = async (
  userId: string,
  petId: string,
  data: UpdatePetDTO,
  isAdmin = false
) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  const parsedDate =
    data.dateOfBirth !== undefined
      ? data.dateOfBirth
        ? new Date(data.dateOfBirth)
        : null
      : undefined;

  const resolvedImageUrl = data.imageUrl ?? data.profilePictureUrl;

  const updatedPet = await prisma.pet.update({
    where: { id: petId },
    data: {
      name: data.name !== undefined ? data.name.trim() : undefined,
      profilePictureUrl: resolvedImageUrl,
      imageUrl: resolvedImageUrl,
      imagePublicId: data.imagePublicId,
      animalType:
        data.animalType !== undefined ? data.animalType.trim() : undefined,
      breed: data.breed !== undefined ? data.breed.trim() : undefined,
      gender: data.gender !== undefined ? data.gender.trim() : undefined,
      dateOfBirth: parsedDate,
      color: data.color !== undefined ? data.color.trim() : undefined,
      personality:
        data.personality !== undefined ? data.personality : undefined,
      vaccinationStatus:
        data.vaccinationStatus !== undefined
          ? data.vaccinationStatus.trim()
          : undefined,
      allergies:
        data.allergies !== undefined ? data.allergies.trim() : undefined,
      description:
        data.description !== undefined ? data.description.trim() : undefined,
    },
    include: {
      images: true,
    },
  });

  return updatedPet;
};

export interface SetPetActivationDTO {
  active: boolean;
  deactivatePetId?: string;
}

/**
 * Handles pet activation and deactivation with concurrency protection (FOR UPDATE)
 * and automatic atomic swapping when limit is reached.
 */
export const setPetActivation = async (
  userId: string,
  petId: string,
  dto: SetPetActivationDTO
) => {
  const { active, deactivatePetId } = dto;

  return await prisma.$transaction(async (tx) => {
    // 1. Lock the owner's user row with SELECT ... FOR UPDATE to prevent concurrent race conditions
    await tx.$queryRaw`SELECT id FROM users WHERE id = ${userId} FOR UPDATE`;

    // 2. Fetch the target pet
    const targetPet = await tx.pet.findFirst({
      where: { id: petId, userId },
      include: { images: true },
    });
    if (!targetPet) {
      throw new AppError("Pet not found or unauthorized", 404);
    }

    // 3. Turning OFF is always allowed
    if (!active) {
      if (!targetPet.isActive) {
        return {
          pet: targetPet,
          deactivatedPet: null,
          message: "Pet is already inactive",
        };
      }
      const updated = await tx.pet.update({
        where: { id: petId },
        data: { isActive: false },
        include: { images: true },
      });
      return {
        pet: updated,
        deactivatedPet: null,
        message: "Pet deactivated successfully",
      };
    }

    // 4. Turning ON: Validate profile completeness
    const missingFields = checkPetProfileCompleteness(targetPet);
    if (missingFields.length > 0) {
      throw new AppError(
        `Cannot activate pet profile. Missing required fields: ${missingFields.join(", ")}`,
        422
      );
    }

    // If already active, return cleanly
    if (targetPet.isActive) {
      return {
        pet: targetPet,
        deactivatedPet: null,
        message: "Pet is already active",
      };
    }

    // 5. Calculate allowedActive slots
    // allowedActive = FREE_ACTIVE_PETS + number of non-expired paid slots owned by user
    const now = new Date();
    const paidSlotsCount = await tx.activeSlotEntitlement.count({
      where: {
        ownerId: userId,
        status: EntitlementStatus.ACTIVE,
        expiresAt: { gt: now },
      },
    });
    const allowedActive = matchingConfig.FREE_ACTIVE_PETS + paidSlotsCount;

    // 6. Count currently active pets for this user
    const currentlyActivePets = await tx.pet.findMany({
      where: { userId, isActive: true },
      select: {
        id: true,
        name: true,
        animalType: true,
        breed: true,
        imageUrl: true,
        profilePictureUrl: true,
      },
    });

    const activeCount = currentlyActivePets.length;

    // Case A: activeCount < allowedActive -> Simply activate
    if (activeCount < allowedActive) {
      const activatedPet = await tx.pet.update({
        where: { id: petId },
        data: {
          isActive: true,
          activatedAt: new Date(),
        },
        include: { images: true },
      });
      return {
        pet: activatedPet,
        deactivatedPet: null,
        message: "Pet activated successfully",
      };
    }

    // Case B: Limit is reached and allowedActive == 1
    // Atomically deactivate the currently active pet and activate this one (swap)
    if (allowedActive === 1) {
      const activePetToDeactivate = currentlyActivePets[0];
      let deactivatedPet = null;
      if (activePetToDeactivate) {
        deactivatedPet = await tx.pet.update({
          where: { id: activePetToDeactivate.id },
          data: { isActive: false },
          include: { images: true },
        });
      }

      const activatedPet = await tx.pet.update({
        where: { id: petId },
        data: {
          isActive: true,
          activatedAt: new Date(),
        },
        include: { images: true },
      });

      return {
        pet: activatedPet,
        deactivatedPet,
        message: `Swapped active pet: ${activatedPet.name} is now active; ${deactivatedPet?.name ?? "previous pet"} deactivated.`,
      };
    }

    // Case C: Limit is reached and allowedActive > 1
    // If deactivatePetId is missing, return 409 ACTIVE_LIMIT_REACHED with active pets list and slot info
    if (!deactivatePetId) {
      const error: any = new AppError(
        "ACTIVE_LIMIT_REACHED: You have reached your maximum active pet limit. Choose a pet to deactivate or purchase an additional slot.",
        409
      );
      error.code = "ACTIVE_LIMIT_REACHED";
      error.details = {
        activePets: currentlyActivePets,
        allowedActive,
        purchasableSlots: {
          available: matchingConfig.MAX_PAID_SLOTS - paidSlotsCount,
          priceNpr: matchingConfig.SLOT_PRICE_NPR,
          durationDays: matchingConfig.SLOT_DURATION_DAYS,
        },
      };
      throw error;
    }

    // Deactivate chosen pet and activate target
    const petToDeactivate = await tx.pet.findFirst({
      where: { id: deactivatePetId, userId, isActive: true },
    });
    if (!petToDeactivate) {
      throw new AppError("Specified deactivatePetId is not currently active or not owned by you", 400);
    }

    const deactivatedPet = await tx.pet.update({
      where: { id: deactivatePetId },
      data: { isActive: false },
      include: { images: true },
    });

    const activatedPet = await tx.pet.update({
      where: { id: petId },
      data: {
        isActive: true,
        activatedAt: new Date(),
      },
      include: { images: true },
    });

    return {
      pet: activatedPet,
      deactivatedPet,
      message: `Swapped active pet: ${activatedPet.name} is now active; ${deactivatedPet.name} deactivated.`,
    };
  });
};

export const deletePetForUser = async (userId: string, petId: string, isAdmin = false) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
    include: { images: true },
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  // Deleting a pet:
  // 1. Deactivates it, cancels its pending requests, ends its matches
  // Wrapped in atomic transaction
  await prisma.$transaction(async (tx) => {
    // Cancel pending connection requests where pet is sender or receiver
    await tx.connectionRequest.updateMany({
      where: {
        OR: [{ senderPetId: petId }, { receiverPetId: petId }],
        status: RequestStatus.PENDING,
      },
      data: {
        status: RequestStatus.DECLINED,
        respondedAt: new Date(),
      },
    });

    // End active matches involving this pet
    await tx.match.updateMany({
      where: {
        OR: [{ petAId: petId }, { petBId: petId }],
        status: MatchStatus.ACTIVE,
      },
      data: {
        status: MatchStatus.ENDED,
        endedAt: new Date(),
        endedBy: userId,
      },
    });

    // Delete pet record (cascades image records, pet_swipes, requests, and matches)
    await tx.pet.delete({
      where: { id: petId },
    });
  });

  // Clean up any associated Cloudinary assets outside transaction
  if (existingPet.imagePublicId) {
    await deleteImage(existingPet.imagePublicId);
  }
  for (const img of existingPet.images) {
    if (img.imagePublicId && img.imagePublicId !== existingPet.imagePublicId) {
      await deleteImage(img.imagePublicId);
    }
  }

  return { id: petId, deleted: true };
};

/**
 * Uploads a pet photo to Cloudinary, attaches it to the Pet record,
 * adds a PetImage record, deletes the old photo if present, and guards against orphans.
 */
export const uploadPetPhoto = async (
  userId: string,
  petId: string,
  fileBuffer: Buffer,
  isAdmin = false
) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  const oldPublicId = existingPet.imagePublicId;
  const uploaded = await uploadImage(fileBuffer, "pets");

  try {
    const updated = await prisma.$transaction(async (tx) => {
      const pet = await tx.pet.update({
        where: { id: petId },
        data: {
          imageUrl: uploaded.imageUrl,
          profilePictureUrl: uploaded.imageUrl,
          imagePublicId: uploaded.imagePublicId,
        },
      });

      await tx.petImage.create({
        data: {
          petId,
          imageUrl: uploaded.imageUrl,
          imagePublicId: uploaded.imagePublicId,
          isMain: true,
        },
      });

      return pet;
    });

    if (oldPublicId && oldPublicId !== uploaded.imagePublicId) {
      await deleteImage(oldPublicId);
    }

    return updated;
  } catch (err) {
    await deleteImage(uploaded.imagePublicId);
    throw err;
  }
};

export const removePetPhoto = async (
  userId: string,
  petId: string,
  isAdmin = false
) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  if (existingPet.imagePublicId) {
    await deleteImage(existingPet.imagePublicId);
  }

  const updatedPet = await prisma.pet.update({
    where: { id: petId },
    data: {
      imageUrl: null,
      profilePictureUrl: null,
      imagePublicId: null,
    },
    include: { images: true },
  });

  return updatedPet;
};

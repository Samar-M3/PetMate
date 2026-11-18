import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { uploadImage, deleteImage } from "../../services/image.service.ts";

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

  const pet = await prisma.pet.create({
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
};

export const getPetsForUser = async (userId: string) => {
  return await prisma.pet.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
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
  // Ensure the pet belongs to the authenticated user (unless admin)
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

export const deletePetForUser = async (userId: string, petId: string, isAdmin = false) => {
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
    include: { images: true },
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  // Clean up any associated Cloudinary assets
  if (existingPet.imagePublicId) {
    await deleteImage(existingPet.imagePublicId);
  }
  for (const img of existingPet.images) {
    if (img.imagePublicId && img.imagePublicId !== existingPet.imagePublicId) {
      await deleteImage(img.imagePublicId);
    }
  }

  await prisma.pet.delete({
    where: { id: petId },
  });

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
  // Ensure the pet belongs to the user (unless admin)
  const whereClause = isAdmin ? { id: petId } : { id: petId, userId };
  const existingPet = await prisma.pet.findFirst({
    where: whereClause,
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  const oldPublicId = existingPet.imagePublicId;

  // Upload to environment-scoped pets folder with generated id
  const uploaded = await uploadImage(fileBuffer, "pets");

  try {
    const updated = await prisma.$transaction(async (tx) => {
      // 1. Update pet main image
      const pet = await tx.pet.update({
        where: { id: petId },
        data: {
          imageUrl: uploaded.imageUrl,
          profilePictureUrl: uploaded.imageUrl,
          imagePublicId: uploaded.imagePublicId,
        },
      });

      // 2. Add to PetImage gallery
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

    // 3. Remove old image if existing
    if (oldPublicId && oldPublicId !== uploaded.imagePublicId) {
      await deleteImage(oldPublicId);
    }

    return {
      imageUrl: updated.imageUrl!,
      imagePublicId: updated.imagePublicId!,
      pet: updated,
    };
  } catch (error) {
    // Prevent orphan Cloudinary image if DB transaction failed
    await deleteImage(uploaded.imagePublicId);
    throw error;
  }
};

/**
 * Removes pet image from Cloudinary and clears imageUrl / imagePublicId in DB.
 */
export const removePetPhoto = async (userId: string, petId: string, isAdmin = false) => {
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

  const updatedPet = await prisma.$transaction(async (tx) => {
    await tx.petImage.deleteMany({
      where: { petId },
    });

    return await tx.pet.update({
      where: { id: petId },
      data: {
        imageUrl: null,
        profilePictureUrl: null,
        imagePublicId: null,
      },
    });
  });

  return { id: petId, imageUrl: null, removed: true };
};

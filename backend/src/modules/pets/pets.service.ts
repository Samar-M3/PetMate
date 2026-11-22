import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export interface CreatePetDTO {
  name: string;
  profilePictureUrl?: string;
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

  const pet = await prisma.pet.create({
    data: {
      userId,
      name: data.name.trim(),
      profilePictureUrl: data.profilePictureUrl || null,
      animalType: data.animalType.trim(),
      breed: data.breed.trim(),
      gender: data.gender.trim(),
      dateOfBirth: parsedDate,
      color: data.color?.trim() || null,
      personality: Array.isArray(data.personality) ? data.personality : [],
      vaccinationStatus: data.vaccinationStatus.trim(),
      allergies: data.allergies?.trim() || null,
      description: data.description?.trim() || null,
    },
  });

  return pet;
};

export const getPetsForUser = async (userId: string) => {
  return await prisma.pet.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
  });
};

export const getPetById = async (userId: string, petId: string) => {
  const pet = await prisma.pet.findFirst({
    where: {
      id: petId,
      userId,
    },
  });

  if (!pet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  return pet;
};

export const updatePetForUser = async (
  userId: string,
  petId: string,
  data: UpdatePetDTO
) => {
  // Ensure the pet belongs to the authenticated user
  const existingPet = await prisma.pet.findFirst({
    where: {
      id: petId,
      userId,
    },
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  const parsedDate = data.dateOfBirth !== undefined
    ? (data.dateOfBirth ? new Date(data.dateOfBirth) : null)
    : undefined;

  const updatedPet = await prisma.pet.update({
    where: { id: petId },
    data: {
      name: data.name !== undefined ? data.name.trim() : undefined,
      profilePictureUrl: data.profilePictureUrl,
      animalType: data.animalType !== undefined ? data.animalType.trim() : undefined,
      breed: data.breed !== undefined ? data.breed.trim() : undefined,
      gender: data.gender !== undefined ? data.gender.trim() : undefined,
      dateOfBirth: parsedDate,
      color: data.color !== undefined ? data.color.trim() : undefined,
      personality: data.personality !== undefined ? data.personality : undefined,
      vaccinationStatus: data.vaccinationStatus !== undefined ? data.vaccinationStatus.trim() : undefined,
      allergies: data.allergies !== undefined ? data.allergies.trim() : undefined,
      description: data.description !== undefined ? data.description.trim() : undefined,
    },
  });

  return updatedPet;
};

export const deletePetForUser = async (userId: string, petId: string) => {
  const existingPet = await prisma.pet.findFirst({
    where: {
      id: petId,
      userId,
    },
  });

  if (!existingPet) {
    throw new AppError("Pet not found or unauthorized", 404);
  }

  await prisma.pet.delete({
    where: { id: petId },
  });

  return { id: petId, deleted: true };
};

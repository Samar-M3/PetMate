import prisma from "../../config/db.ts";
import bcrypt from "bcryptjs";
import { firebaseAuth } from "../../config/firebase.ts";
import { Role } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { CreateVeterinarianAccountInput } from "./veterinarians.validation.ts";

export const listVeterinarians = async () => {
  return prisma.veterinarian.findMany({
    orderBy: { createdAt: "desc" },
  });
};

export const findVetByUser = async (userId?: string) => {
  if (userId) {
    const vet = await prisma.veterinarian.findUnique({ where: { userId } });
    if (vet) return vet;
    // Keep profiles created before veterinarian/user linking working.
    return prisma.veterinarian.findFirst({ where: { id: userId } });
  }
  return null;
};

export const createVeterinarianAccount = async (
  actorId: string,
  data: CreateVeterinarianAccountInput,
) => {
  const existingUser = await prisma.user.findFirst({
    where: { email: { equals: data.email, mode: "insensitive" } },
    select: { id: true },
  });
  if (existingUser) {
    throw new AppError("An account with this email already exists", 409);
  }

  let firebaseUser;
  try {
    firebaseUser = await firebaseAuth.createUser({
      email: data.email,
      password: data.password,
      displayName: data.name,
      emailVerified: false,
    });
  } catch (error: any) {
    if (error?.code === "auth/email-already-exists") {
      throw new AppError("An account with this email already exists", 409);
    }
    if (error?.code === "auth/invalid-password") {
      throw new AppError("Temporary password does not meet Firebase requirements", 400);
    }
    if (error?.code === "auth/invalid-email") {
      throw new AppError("A valid email address is required", 400);
    }
    throw new AppError("Could not create the veterinarian authentication account", 502);
  }

  try {
    const temporaryPasswordHash = await bcrypt.hash(data.password, 12);
    const created = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          firebaseUid: firebaseUser.uid,
          email: data.email,
          role: Role.VETERINARIAN,
          isActive: true,
          onboardingCompleted: true,
          mustChangePassword: true,
          profile: { create: { fullName: data.name } },
          veterinarian: {
            create: {
              name: data.name,
              clinicName: data.clinicName,
              specialty: data.specialty,
              address: data.address,
              licenseNumber: data.licenseNumber || null,
              fee: data.fee,
              isVerified: true,
              isAcceptingBookings: data.isAcceptingBookings,
            },
          },
          passwordSetup: {
            create: { temporaryPasswordHash },
          },
        },
        include: { veterinarian: true },
      });

      await tx.adminAuditLog.create({
        data: {
          actorId,
          targetId: user.id,
          action: "CREATE_VETERINARIAN_ACCOUNT",
          newValue: `VETERINARIAN account created for ${data.email}`,
        },
      });

      return user.veterinarian;
    });

    if (!created) {
      throw new AppError("Veterinarian profile could not be created", 500);
    }

    return {
      veterinarian: created,
      account: { email: data.email, role: Role.VETERINARIAN, mustChangePassword: true },
    };
  } catch (error) {
    try {
      await firebaseAuth.deleteUser(firebaseUser.uid);
    } catch (cleanupError) {
      console.error(
        "[VeterinariansService] Could not roll back Firebase account after database failure:",
        cleanupError,
      );
    }
    throw error;
  }
};

export const updateVeterinarianRecord = async (
  id: string,
  data: {
    name?: string;
    clinicName?: string;
    specialty?: string;
    address?: string;
    fee?: number;
    isAcceptingBookings?: boolean;
  }
) => {
  return prisma.veterinarian.update({
    where: { id },
    data,
  });
};

export const updateVetSlotsRecord = async (
  id: string,
  availableSlots: string[],
  ownerId: string,
) => {
  const veterinarian = await prisma.veterinarian.findUnique({
    where: { id },
    select: { userId: true },
  });
  if (!veterinarian) throw new AppError("Veterinarian profile not found", 404);
  if (veterinarian.userId !== ownerId && veterinarian.userId !== null) {
    throw new AppError("You can only update your own availability", 403);
  }
  if (veterinarian.userId === null && id !== ownerId) {
    throw new AppError("You can only update your own availability", 403);
  }

  return prisma.veterinarian.update({
    where: { id },
    data: { availableSlots },
  });
};

export const deleteVeterinarian = async (id: string) => {
  return prisma.veterinarian.delete({ where: { id } });
};

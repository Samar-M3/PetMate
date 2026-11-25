import prisma from "../../config/db.ts";
import bcrypt from "bcryptjs";
import { firebaseAuth } from "../../config/firebase.ts";

export const listVeterinarians = async () => {
  return prisma.veterinarian.findMany({
    orderBy: { createdAt: "desc" },
  });
};

export const findVetByUser = async (userId?: string, email?: string) => {
  if (userId) {
    const vet = await prisma.veterinarian.findFirst({ where: { id: userId } });
    if (vet) return vet;
  }
  if (email) {
    const vet = await prisma.veterinarian.findFirst({ where: { email } });
    if (vet) return vet;
  }
  return null;
};

export const createVeterinarian = async (data: {
  name: string;
  email: string;
  password: string;
  clinicName: string;
  specialty: string;
  address: string;
  fee?: number;
  rating?: number;
  availableSlots?: string[];
  isVerified?: boolean;
  isAcceptingBookings?: boolean;
}) => {
  const passwordHash = await bcrypt.hash(data.password, 10);
  const vet = await prisma.veterinarian.create({
    data: {
      name: data.name,
      email: data.email,
      passwordHash,
      clinicName: data.clinicName,
      specialty: data.specialty,
      address: data.address,
      fee: data.fee || 500,
      rating: data.rating || 5.0,
      availableSlots: data.availableSlots || [
        "10:00 AM",
        "01:00 PM",
        "03:30 PM",
      ],
      isVerified: data.isVerified ?? true,
      isAcceptingBookings: data.isAcceptingBookings ?? true,
    },
  });

  // Ensure Firebase user and User record exist for seamless main landing page login
  try {
    let fbUid = vet.id;
    try {
      const existing = await firebaseAuth.getUserByEmail(data.email);
      await firebaseAuth.updateUser(existing.uid, { password: data.password });
      fbUid = existing.uid;
    } catch {
      const created = await firebaseAuth.createUser({
        email: data.email,
        password: data.password,
        displayName: data.name,
      });
      fbUid = created.uid;
    }

    await prisma.user.upsert({
      where: { firebaseUid: fbUid },
      update: {
        role: "VETERINARIAN",
        isActive: true,
        onboardingCompleted: true,
        email: data.email,
      },
      create: {
        id: vet.id,
        firebaseUid: fbUid,
        email: data.email,
        role: "VETERINARIAN",
        isActive: true,
        onboardingCompleted: true,
        profile: {
          create: {
            fullName: data.name,
          },
        },
      },
    });
  } catch (err) {
    console.warn("Could not pre-create Firebase user for vet:", err);
  }

  return vet;
};

export const verifyVetPassword = async (vetId: string, password: string): Promise<boolean> => {
  const vet = await prisma.veterinarian.findUnique({ where: { id: vetId } });
  if (!vet || !vet.passwordHash) return false;
  return bcrypt.compare(password, vet.passwordHash);
};

export const findVetByEmail = async (email: string) => {
  return prisma.veterinarian.findFirst({ where: { email } });
};

export const ensureVetUser = async (vet: { id: string; email: string | null; name: string }) => {
  return prisma.user.upsert({
    where: { firebaseUid: vet.id },
    update: {
      role: "VETERINARIAN",
      isActive: true,
      onboardingCompleted: true,
      ...(vet.email ? { email: vet.email } : {}),
    },
    create: {
      id: vet.id,
      firebaseUid: vet.id,
      email: vet.email,
      role: "VETERINARIAN",
      isActive: true,
      onboardingCompleted: true,
      profile: {
        create: {
          fullName: vet.name,
        },
      },
    },
  });
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

export const updateVetSlotsRecord = async (id: string, availableSlots: string[]) => {
  return prisma.veterinarian.update({
    where: { id },
    data: { availableSlots },
  });
};

export const deleteVeterinarian = async (id: string) => {
  return prisma.veterinarian.delete({ where: { id } });
};

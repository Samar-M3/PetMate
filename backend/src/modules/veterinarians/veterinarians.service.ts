import prisma from "../../config/db.ts";

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
  return null;
};

export const createVeterinarian = async (data: {
  name: string;
  clinicName: string;
  specialty: string;
  address: string;
  fee?: number;
  rating?: number;
  availableSlots?: string[];
  isVerified?: boolean;
  isAcceptingBookings?: boolean;
}) => {
  return prisma.veterinarian.create({
    data: {
      name: data.name,
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

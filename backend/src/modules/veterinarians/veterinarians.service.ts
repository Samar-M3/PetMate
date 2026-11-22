import prisma from "../../config/db.ts";

export const listVeterinarians = async () => {
  return prisma.veterinarian.findMany({
    orderBy: { createdAt: "desc" },
  });
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

export const deleteVeterinarian = async (id: string) => {
  return prisma.veterinarian.delete({ where: { id } });
};

import prisma from "../../config/db.ts";
import { Role } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const listAppointments = async (userId: string, userRole: string, vetId?: string) => {
  if (userRole === "ADMIN") {
    return prisma.appointment.findMany({
      include: { vet: true },
      orderBy: { createdAt: "desc" },
    });
  }
  if (userRole === "VETERINARIAN" || vetId) {
    const vet = vetId
      ? { id: vetId }
      : await prisma.veterinarian.findFirst({
          where: { OR: [{ userId }, { id: userId }] },
        });
    if (!vet) return [];
    return prisma.appointment.findMany({
      where: { vetId: vet.id },
      include: { vet: true },
      orderBy: { createdAt: "desc" },
    });
  }
  return prisma.appointment.findMany({
    where: { userId },
    include: { vet: true },
    orderBy: { createdAt: "desc" },
  });
};

export const createAppointment = async (userId: string, data: {
  petName: string;
  vetId: string;
  date: string;
  timeSlot: string;
  reason: string;
}) => {
  return prisma.appointment.create({
    data: {
      userId,
      petName: data.petName,
      vetId: data.vetId,
      date: data.date,
      timeSlot: data.timeSlot,
      reason: data.reason || "General Checkup",
      status: "UPCOMING",
    },
    include: { vet: true },
  });
};

export const updateAppointmentStatus = async (
  id: string,
  status: string,
  vetNotes?: string,
  nextVaccineDue?: string,
  actor?: { userId: string; role: Role },
) => {
  const appointment = await prisma.appointment.findUnique({
    where: { id },
    include: { vet: { select: { userId: true } } },
  });
  if (!appointment) throw new AppError("Appointment not found", 404);
  if (
    actor?.role === Role.VETERINARIAN &&
    appointment.vet.userId !== actor.userId &&
    !(appointment.vet.userId === null && appointment.vetId === actor.userId)
  ) {
    throw new AppError("You can only update appointments assigned to you", 403);
  }

  return prisma.appointment.update({
    where: { id },
    data: {
      status: status as any,
      ...(vetNotes !== undefined && { vetNotes }),
      ...(nextVaccineDue !== undefined && { nextVaccineDue }),
    },
    include: { vet: true },
  });
};

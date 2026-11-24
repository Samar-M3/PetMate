import prisma from "../../config/db.ts";

export const listAppointments = async (userId: string, userRole: string, vetId?: string) => {
  if (userRole === "ADMIN") {
    return prisma.appointment.findMany({
      include: { vet: true },
      orderBy: { createdAt: "desc" },
    });
  }
  if (userRole === "VETERINARIAN" || vetId) {
    const vet = vetId ? { id: vetId } : await prisma.veterinarian.findFirst({ where: { id: userId } });
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
  nextVaccineDue?: string
) => {
  return prisma.appointment.update({
    where: { id },
    data: {
      status,
      ...(vetNotes !== undefined && { vetNotes }),
      ...(nextVaccineDue !== undefined && { nextVaccineDue }),
    },
    include: { vet: true },
  });
};

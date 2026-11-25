import prisma from "../../config/db.ts";
import { Role } from "../../generated/prisma/client.ts";
import { AppointmentStatus } from "../../generated/prisma/enums.ts";
import { NotificationService } from "../../services/notification.service.ts";
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
  // Validate veterinarian exists and is accepting bookings
  const vet = await prisma.veterinarian.findUnique({
    where: { id: data.vetId },
  });

  if (!vet) {
    throw new AppError("Veterinarian not found", 404);
  }

  if (!vet.isVerified) {
    throw new AppError("This veterinarian is not verified", 400);
  }

  if (!vet.isAcceptingBookings) {
    throw new AppError("This veterinarian is not currently accepting bookings", 400);
  }

  // Validate time slot is in vet's available slots
  if (!vet.availableSlots.includes(data.timeSlot)) {
    throw new AppError("Selected time slot is not available for this veterinarian", 400);
  }

  // Check if time slot is already booked for this vet on this date
  const existingAppointment = await prisma.appointment.findFirst({
    where: {
      vetId: data.vetId,
      date: data.date,
      timeSlot: data.timeSlot,
      status: { in: ["UPCOMING", "COMPLETED"] },
    },
  });

  if (existingAppointment) {
    throw new AppError("This time slot has already been booked", 409);
  }

  // Verify pet belongs to user (if user has pets)
  const userPets = await prisma.pet.findMany({
    where: {
      userId,
      isActive: true,
      name: data.petName,
    },
  });

  if (userPets.length === 0) {
    throw new AppError("Pet not found or not owned by you", 404);
  }

  // Get user info for notification
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });

  const appointment = await prisma.appointment.create({
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

  // Send notification to veterinarian
  try {
    await NotificationService.sendAppointmentNotification(
      appointment.vetId,
      {
        type: 'NEW_APPOINTMENT',
        appointmentId: appointment.id,
        petName: appointment.petName,
        date: appointment.date,
        timeSlot: appointment.timeSlot,
        ownerName: user?.profile?.fullName || user?.email || 'Pet Owner',
      }
    );
  } catch (err) {
    console.error("[AppointmentsService] Failed to send appointment notification:", err);
  }

  return appointment;
};

export const updateAppointmentStatus = async (
  id: string,
  status: AppointmentStatus,
  vetNotes?: string,
  nextVaccineDue?: string,
  actor?: { userId: string; role: Role },
) => {
  const appointment = await prisma.appointment.findUnique({
    where: { id },
    include: { vet: true },
  });
  if (!appointment) throw new AppError("Appointment not found", 404);
  if (
    actor?.role === Role.VETERINARIAN &&
    appointment.vetId !== actor.userId
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

export const getBookedSlots = async (vetId: string, date: string) => {
  const appointments = await prisma.appointment.findMany({
    where: {
      vetId,
      date,
      status: { in: ["UPCOMING", "COMPLETED"] },
    },
    select: { timeSlot: true },
  });
  return appointments.map((a) => a.timeSlot);
};

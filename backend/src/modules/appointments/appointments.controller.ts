import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  listAppointments,
  createAppointment,
  updateAppointmentStatus,
  getBookedSlots,
} from "./appointments.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getAppointments = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id || req.firebaseUid || "";
    const role = req.user?.role || "PET_OWNER";
    const appointments = await listAppointments(userId, role);
    sendSuccess(res, {
      statusCode: 200,
      message: "Appointments retrieved successfully",
      data: { appointments },
    });
  } catch (error) {
    next(error);
  }
};

export const bookAppointment = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id || req.firebaseUid || "";
    const { petName, vetId, date, timeSlot } = req.body;
    if (!petName || !vetId || !date || !timeSlot) {
      return next(new AppError("petName, vetId, date, and timeSlot are required", 400));
    }
    const appointment = await createAppointment(userId, req.body);
    sendSuccess(res, {
      statusCode: 201,
      message: "Appointment booked successfully",
      data: { appointment },
    });
  } catch (error) {
    next(error);
  }
};

export const updateStatus = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const { status, vetNotes, nextVaccineDue } = req.body;
    const appointment = await updateAppointmentStatus(
      id as string,
      status,
      vetNotes,
      nextVaccineDue
    );
    sendSuccess(res, {
      statusCode: 200,
      message: "Appointment status updated successfully",
      data: { appointment },
    });
  } catch (error) {
    next(error);
  }
};

export const getBookedSlotsHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { vetId, date } = req.query;
    if (!vetId || !date) {
      return next(new AppError("vetId and date are required", 400));
    }
    const bookedSlots = await getBookedSlots(vetId as string, date as string);
    sendSuccess(res, {
      statusCode: 200,
      message: "Booked slots retrieved successfully",
      data: { bookedSlots },
    });
  } catch (error) {
    next(error);
  }
};

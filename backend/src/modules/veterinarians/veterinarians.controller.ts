import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  listVeterinarians,
  findVetByUser,
  createVeterinarian,
  updateVeterinarianRecord,
  updateVetSlotsRecord,
  deleteVeterinarian,
} from "./veterinarians.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getVeterinarians = async (
  _req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const veterinarians = await listVeterinarians();
    sendSuccess(res, {
      statusCode: 200,
      message: "Veterinarians retrieved successfully",
      data: { veterinarians },
    });
  } catch (error) {
    next(error);
  }
};

export const getMyVetProfile = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id;
    const email = req.firebaseUser?.email;
    const veterinarian = await findVetByUser(userId, email);
    if (!veterinarian) {
      return next(new AppError("Veterinarian profile not found", 404));
    }
    sendSuccess(res, {
      statusCode: 200,
      message: "Veterinarian profile retrieved successfully",
      data: { veterinarian },
    });
  } catch (error) {
    next(error);
  }
};

export const addVeterinarian = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { name, clinicName, specialty, address } = req.body;
    if (!name || !clinicName || !specialty || !address) {
      return next(
        new AppError(
          "name, clinicName, specialty, and address are required",
          400
        )
      );
    }

    const veterinarian = await createVeterinarian(req.body);
    sendSuccess(res, {
      statusCode: 201,
      message: "Veterinarian registered successfully",
      data: { veterinarian },
    });
  } catch (error) {
    next(error);
  }
};

export const updateVeterinarian = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const veterinarian = await updateVeterinarianRecord(id as string, req.body);
    sendSuccess(res, {
      statusCode: 200,
      message: "Veterinarian updated successfully",
      data: { veterinarian },
    });
  } catch (error) {
    next(error);
  }
};

export const updateVetSlots = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const { availableSlots } = req.body;
    const veterinarian = await updateVetSlotsRecord(id as string, availableSlots || []);
    sendSuccess(res, {
      statusCode: 200,
      message: "Veterinarian slots updated successfully",
      data: { veterinarian },
    });
  } catch (error) {
    next(error);
  }
};

export const removeVeterinarian = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    await deleteVeterinarian(id as string);
    sendSuccess(res, {
      statusCode: 200,
      message: "Veterinarian deleted successfully",
      data: null,
    });
  } catch (error) {
    next(error);
  }
};

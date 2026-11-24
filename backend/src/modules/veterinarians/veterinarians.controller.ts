import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  listVeterinarians,
  findVetByUser,
  createVeterinarianAccount,
  updateVeterinarianRecord,
  updateVetSlotsRecord,
  deleteVeterinarian,
} from "./veterinarians.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { validateCreateVeterinarianAccount } from "./veterinarians.validation.ts";

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
    const veterinarian = await findVetByUser(userId);
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
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const input = validateCreateVeterinarianAccount(req.body);
    const result = await createVeterinarianAccount(req.user.id, input);
    sendSuccess(res, {
      statusCode: 201,
      message: "Veterinarian account created. The veterinarian must set a new password at first login.",
      data: result,
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
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }
    const { id } = req.params;
    const { availableSlots } = req.body;
    if (!Array.isArray(availableSlots) || availableSlots.some((slot) => typeof slot !== "string")) {
      return next(new AppError("availableSlots must be an array of strings", 400));
    }
    const veterinarian = await updateVetSlotsRecord(
      id as string,
      availableSlots,
      req.user.id,
    );
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

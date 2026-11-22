import type { Request, Response, NextFunction } from "express";
import {
  listVeterinarians,
  createVeterinarian,
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

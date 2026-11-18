import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  createPetForUser,
  getPetsForUser,
  getPetById,
  updatePetForUser,
  deletePetForUser,
} from "./pets.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const createPet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const pet = await createPetForUser(req.user.id, req.body);

    sendSuccess(res, {
      statusCode: 201,
      message: "Pet created successfully",
      data: { pet },
    });
  } catch (error) {
    next(error);
  }
};

export const getPets = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const pets = await getPetsForUser(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Pets retrieved successfully",
      data: { pets },
    });
  } catch (error) {
    next(error);
  }
};

export const getSinglePet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const pet = await getPetById(req.user.id, req.params.id as string);

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet retrieved successfully",
      data: { pet },
    });
  } catch (error) {
    next(error);
  }
};

export const updatePet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const pet = await updatePetForUser(req.user.id, req.params.id as string, req.body);

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet updated successfully",
      data: { pet },
    });
  } catch (error) {
    next(error);
  }
};

export const deletePet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const result = await deletePetForUser(req.user.id, req.params.id as string);

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet deleted successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

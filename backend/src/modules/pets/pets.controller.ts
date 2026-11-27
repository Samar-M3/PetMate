import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { Role } from "../../middleware/auth.middleware.ts";
import {
  createPetForUser,
  createOnboardingPet,
  patchPetForUser,
  getPetsForUser,
  getPetById,
  getPublicPetProfile,
  updatePetForUser,
  setPetActivation,
  deletePetForUser,
  uploadPetPhoto,
  removePetPhoto,
} from "./pets.service.ts";
import {
  validateCreateOnboardingPet,
  validatePatchPet,
} from "./pets.validation.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

const isAdmin = (req: AuthenticatedRequest): boolean =>
  req.user?.role === Role.ADMIN;

export const createPet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const isOnboardingPayload =
      req.body &&
      typeof req.body === "object" &&
      ("species" in req.body || Array.isArray(req.body.photos));

    const pet = isOnboardingPayload
      ? await createOnboardingPet(
          req.user.id,
          validateCreateOnboardingPet(req.body)
        )
      : await createPetForUser(req.user.id, req.body);

    sendSuccess(res, {
      statusCode: 201,
      message: "Pet created successfully",
      data: { pet },
    });
  } catch (error) {
    next(error);
  }
};

export const patchPet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const input = validatePatchPet(req.body);
    const pet = await patchPetForUser(
      req.user.id,
      req.params.id as string,
      input
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet updated successfully",
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

export const getPublicPet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 401));
    }

    const pet = await getPublicPetProfile(req.user.id, req.params.id as string);

    sendSuccess(res, {
      statusCode: 200,
      message: "Public pet profile retrieved successfully",
      data: { pet },
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

    const pet = await getPetById(req.user.id, req.params.id as string, isAdmin(req));

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

    const pet = await updatePetForUser(
      req.user.id,
      req.params.id as string,
      req.body,
      isAdmin(req)
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet updated successfully",
      data: { pet },
    });
  } catch (error) {
    next(error);
  }
};

export const activatePet = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const petId = req.params.id as string;
    const { active, deactivatePetId } = req.body;

    if (active === undefined || typeof active !== "boolean") {
      return next(new AppError("Field 'active' (boolean) is required in request body", 400));
    }

    const result = await setPetActivation(req.user.id, petId, {
      active,
      deactivatePetId,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: result.message,
      data: result,
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

    const result = await deletePetForUser(
      req.user.id,
      req.params.id as string,
      isAdmin(req)
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet deleted successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const uploadPetImage = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const petId = req.params.id as string;
    const file = req.file;

    if (!file) {
      return next(new AppError("No image file provided in request", 400));
    }

    const updatedPet = await uploadPetPhoto(
      req.user.id,
      petId,
      file.buffer,
      isAdmin(req)
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet photo uploaded successfully",
      data: { pet: updatedPet },
    });
  } catch (error) {
    next(error);
  }
};

export const deletePetImageHandler = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const petId = req.params.id as string;
    const updatedPet = await removePetPhoto(req.user.id, petId, isAdmin(req));

    sendSuccess(res, {
      statusCode: 200,
      message: "Pet photo removed successfully",
      data: { pet: updatedPet },
    });
  } catch (error) {
    next(error);
  }
};

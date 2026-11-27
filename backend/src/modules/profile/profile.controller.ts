import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import {
  getOwnerProfile,
  updateOwnerProfileStep1,
  completeOwnerOnboarding,
} from "./profile.service.ts";
import { validateUpdateProfileMe } from "./profile.validation.ts";

export const getMeProfile = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }
    const profile = await getOwnerProfile(req.user.id);
    sendSuccess(res, {
      statusCode: 200,
      message: "Owner profile retrieved successfully",
      data: { profile },
    });
  } catch (error) {
    next(error);
  }
};

export const putMeProfile = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }
    const input = validateUpdateProfileMe(req.body);
    const profile = await updateOwnerProfileStep1(req.user.id, input);
    sendSuccess(res, {
      statusCode: 200,
      message: "Profile saved successfully",
      data: { profile },
    });
  } catch (error) {
    next(error);
  }
};

export const postCompleteProfile = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }
    const petId =
      typeof req.body?.petId === "string" && req.body.petId.trim().length > 0
        ? req.body.petId.trim()
        : undefined;
    const result = await completeOwnerOnboarding(req.user.id, petId);
    sendSuccess(res, {
      statusCode: 200,
      message: "Onboarding completed successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

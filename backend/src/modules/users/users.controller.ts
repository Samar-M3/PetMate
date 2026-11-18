import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  initializeUserRecord,
  getUserDetails,
  updateOwnerProfile,
  updateUserAvatar,
  getOnboardingStatus,
} from "./users.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const initializeUser = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    console.log(`[UsersController] 👤 Handling POST /users/initialize for UID: ${req.firebaseUid}`);
    if (!req.firebaseUid) {
      return next(new AppError("Missing Firebase UID in request context", 401));
    }

    const { phoneNumber } = req.body;
    const email = req.firebaseUser?.email;

    const user = await initializeUserRecord(req.firebaseUid, email, phoneNumber);
    console.log(`[UsersController] ✅ PostgreSQL user initialized successfully: ID ${user.id} (email: ${user.email})`);

    sendSuccess(res, {
      statusCode: 200,
      message: "User initialized successfully",
      data: { user },
    });
  } catch (error) {
    console.error("[UsersController] ❌ Error in initializeUser:", error);
    next(error);
  }
};

export const getMe = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const user = await getUserDetails(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "User profile fetched successfully",
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

export const updateMe = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    // Strip role and isActive — never accept from client
    const {
      role: _ignoreRole,
      isActive: _ignoreActive,
      fullName,
      profilePictureUrl,
      imageUrl,
      imagePublicId,
      location,
      area,
      bio,
      phoneNumber,
      onboardingCompleted,
    } = req.body;

    const user = await updateOwnerProfile(req.user.id, {
      fullName,
      profilePictureUrl,
      imageUrl,
      imagePublicId,
      location,
      area,
      bio,
      phoneNumber,
      onboardingCompleted,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Owner profile updated successfully",
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

export const uploadAvatar = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    if (!req.file || !req.file.buffer) {
      return next(new AppError("Image file is required under form field 'image'", 400));
    }

    const result = await updateUserAvatar(req.user.id, req.file.buffer);

    sendSuccess(res, {
      statusCode: 200,
      message: "Avatar uploaded successfully to Cloudinary",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getStatus = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    console.log(`[UsersController] 🔍 Handling GET /users/onboarding-status for UID: ${req.firebaseUid}`);
    if (!req.firebaseUid) {
      return next(new AppError("Missing Firebase UID in request context", 401));
    }

    const status = await getOnboardingStatus(req.firebaseUid);
    console.log(`[UsersController] ✅ Status for UID ${req.firebaseUid}: nextStep=${status.nextStep}, completed=${status.onboardingCompleted}`);

    sendSuccess(res, {
      statusCode: 200,
      message: "Onboarding status retrieved",
      data: status,
    });
  } catch (error) {
    console.error("[UsersController] ❌ Error in getStatus:", error);
    next(error);
  }
};

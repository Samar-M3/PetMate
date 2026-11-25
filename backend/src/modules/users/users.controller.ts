import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { invalidateUserCacheById } from "../../middleware/auth.middleware.ts";
import {
  initializeUserRecord,
  getUserDetails,
  getPublicUserProfile,
  updateOwnerProfile,
  updateUserAvatar,
  getOnboardingStatus,
  submitRoleApplication,
  blockUser,
  completeInitialVeterinarianPassword,
} from "./users.service.ts";
import {
  validateInitializeUser,
  validateUpdateOwnerProfile,
} from "./users.validation.ts";
import { validateInitialVeterinarianPassword } from "../veterinarians/veterinarians.validation.ts";
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

    if (req.body && req.body.role !== undefined) {
      return next(new AppError("Role cannot be set or updated through this endpoint", 403));
    }

    const validatedData = validateInitializeUser(req.body || {});
    const phoneNumber = validatedData.phoneNumber;
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

export const changeInitialVeterinarianPassword = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    if (!req.firebaseUid || !req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const newPassword = validateInitialVeterinarianPassword(req.body);
    const user = await completeInitialVeterinarianPassword(
      req.firebaseUid,
      newPassword,
    );
    invalidateUserCacheById(user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Password updated successfully",
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

export const getPublicUser = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 401));
    }

    const user = await getPublicUserProfile(req.user.id, req.params.id as string);

    sendSuccess(res, {
      statusCode: 200,
      message: "Public user profile fetched successfully",
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

const ALLOWED_UPDATE_ME_FIELDS = new Set([
  "fullName",
  "profilePictureUrl",
  "imageUrl",
  "imagePublicId",
  "location",
  "area",
  "bio",
  "phoneNumber",
  "onboardingCompleted",
]);

export const updateMe = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    // Explicit check for role tampering
    if (req.body && req.body.role !== undefined) {
      return next(new AppError("Role cannot be set or updated through this endpoint", 403));
    }
    if (req.body && req.body.isActive !== undefined) {
      return next(new AppError("Account status cannot be modified through this endpoint", 403));
    }

    // Allowlist validation
    if (req.body && typeof req.body === "object") {
      for (const key of Object.keys(req.body)) {
        if (!ALLOWED_UPDATE_ME_FIELDS.has(key)) {
          return next(new AppError(`Invalid field in request body: ${key}`, 400));
        }
      }
    }

    const validatedBody = validateUpdateOwnerProfile(req.body || {});

    const {
      fullName,
      profilePictureUrl,
      imageUrl,
      imagePublicId,
      location,
      area,
      bio,
      phoneNumber,
      onboardingCompleted,
    } = validatedBody as any;

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

export const applyRole = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const { type, notes } = req.body || {};
    if (!type || (type !== "SELLER" && type !== "VETERINARIAN")) {
      return next(
        new AppError("type is required and must be SELLER or VETERINARIAN", 400)
      );
    }

    const application = await submitRoleApplication(req.user.id, type, notes);

    sendSuccess(res, {
      statusCode: 201,
      message: "Role application submitted successfully",
      data: { application },
    });
  } catch (error) {
    next(error);
  }
};

export const blockUserController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not found", 404));
    }

    const { id } = req.params;
    if (!id || typeof id !== "string") {
      return next(new AppError("User id is required", 400));
    }

    const result = await blockUser(req.user.id, id.trim());

    sendSuccess(res, {
      statusCode: 200,
      message: "User blocked successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

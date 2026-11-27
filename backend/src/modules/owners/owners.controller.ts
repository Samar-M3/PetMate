import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import {
  getNearbyOwners,
  updateAuthenticatedOwnerLocation,
  updateAuthenticatedOwnerVisibility,
} from "./owners.service.ts";
import {
  validateNearbyQuery,
  validateUpdateLocation,
  validateUpdateVisibility,
} from "./owners.validation.ts";

export const updateLocationController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const input = validateUpdateLocation(req.body || {});
    const result = await updateAuthenticatedOwnerLocation({
      userId: req.user.id,
      latitude: input.latitude,
      longitude: input.longitude,
      area: input.area,
      locationEnabled: input.locationEnabled,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Location updated successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getNearbyOwnersController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const query = validateNearbyQuery(req.query);
    const result = await getNearbyOwners({
      userId: req.user.id,
      radius: query.radius,
      page: query.page,
      limit: query.limit,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Nearby pet owners fetched successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const updateLocationVisibilityController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const input = validateUpdateVisibility(req.body || {});
    const result = await updateAuthenticatedOwnerVisibility(
      req.user.id,
      input.locationEnabled
    );

    sendSuccess(res, {
      statusCode: 200,
      message: input.locationEnabled
        ? "Location visibility enabled"
        : "Location visibility disabled",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

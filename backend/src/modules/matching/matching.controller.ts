import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  getDiscoverFeed,
  recordSwipe,
  getIncomingRequests,
  acceptConnectionRequest,
  rejectConnectionRequest,
  SwipeAction,
} from "./matching.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getDiscover = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const petId = req.query.petId as string;
    if (!petId || petId.trim() === "") {
      return next(new AppError("petId query parameter is required", 400));
    }

    const cursor = (req.query.cursor as string) || undefined;
    const limit = parseInt(req.query.limit as string) || 10;

    const result = await getDiscoverFeed({
      userId: req.user.id,
      petId: petId.trim(),
      cursor,
      limit,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Discover feed retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const postSwipe = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { petId, targetPetId, action } = req.body;

    if (!petId || typeof petId !== "string") {
      return next(new AppError("petId (string) is required in request body", 400));
    }
    if (!targetPetId || typeof targetPetId !== "string") {
      return next(
        new AppError("targetPetId (string) is required in request body", 400)
      );
    }
    if (!action || !Object.values(SwipeAction).includes(action)) {
      return next(
        new AppError(
          `action must be one of: ${Object.values(SwipeAction).join(", ")}`,
          400
        )
      );
    }

    const result = await recordSwipe({
      userId: req.user.id,
      petId: petId.trim(),
      targetPetId: targetPetId.trim(),
      action: action as SwipeAction,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Swipe recorded successfully",
      data: { status: result.status },
    });
  } catch (error) {
    next(error);
  }
};

export const getIncoming = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const cursor = (req.query.cursor as string) || undefined;
    const limit = parseInt(req.query.limit as string) || 20;

    const result = await getIncomingRequests({
      userId: req.user.id,
      cursor,
      limit,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Incoming requests retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const acceptRequest = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const requestId = req.params.id as string;
    if (!requestId || requestId.trim() === "") {
      return next(new AppError("Request ID is required", 400));
    }

    const result = await acceptConnectionRequest(req.user.id, requestId.trim());

    sendSuccess(res, {
      statusCode: 200,
      message: "Connection request accepted successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const rejectRequest = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const requestId = req.params.id as string;
    if (!requestId || requestId.trim() === "") {
      return next(new AppError("Request ID is required", 400));
    }

    const result = await rejectConnectionRequest(req.user.id, requestId.trim());

    sendSuccess(res, {
      statusCode: 200,
      message: "Connection request rejected successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

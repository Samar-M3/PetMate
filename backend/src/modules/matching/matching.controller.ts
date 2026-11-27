import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  getDeckFeed,
  recordSwipe,
  undoLastPassSwipe,
  resetPassSwipes,
  getIncomingRequests,
  acceptConnectionRequest,
  rejectConnectionRequest,
  getUserMatches,
  getMatchChat,
  unmatchMatch,
  SwipeAction,
} from "./matching.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getDeck = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const actingPetId = (req.query.actingPetId as string) || (req.query.petId as string);
    if (!actingPetId || actingPetId.trim() === "") {
      return next(new AppError("actingPetId query parameter is required", 400));
    }

    const cursor = (req.query.cursor as string) || undefined;
    const limit = parseInt(req.query.limit as string) || 20;
    const species = (req.query.species as string) || (req.query.animalType as string) || undefined;
    const breed = (req.query.breed as string) || undefined;
    const area = (req.query.area as string) || undefined;
    const ageMin = req.query.ageMin ? parseInt(req.query.ageMin as string) : undefined;
    const ageMax = req.query.ageMax ? parseInt(req.query.ageMax as string) : undefined;

    const result = await getDeckFeed({
      userId: req.user.id,
      actingPetId: actingPetId.trim(),
      cursor,
      limit,
      species,
      breed,
      ageMin,
      ageMax,
      area,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Deck feed retrieved successfully",
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

    const { petId, actingPetId, targetPetId, action } = req.body;
    const effectivePetId = actingPetId || petId;

    if (!effectivePetId || typeof effectivePetId !== "string") {
      return next(new AppError("petId or actingPetId (string) is required in request body", 400));
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
      petId: effectivePetId.trim(),
      targetPetId: targetPetId.trim(),
      action: action as SwipeAction,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: result.matched ? "It's a Match!" : "Swipe recorded successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const postUndoSwipe = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { petId, actingPetId } = req.body;
    const effectivePetId = actingPetId || petId;

    if (!effectivePetId || typeof effectivePetId !== "string") {
      return next(new AppError("petId or actingPetId (string) is required in request body", 400));
    }

    const result = await undoLastPassSwipe({
      userId: req.user.id,
      petId: effectivePetId.trim(),
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

export const postResetPasses = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { petId, actingPetId } = req.body;
    const effectivePetId = actingPetId || petId;

    if (!effectivePetId || typeof effectivePetId !== "string") {
      return next(new AppError("petId or actingPetId (string) is required in request body", 400));
    }

    const result = await resetPassSwipes({
      userId: req.user.id,
      petId: effectivePetId.trim(),
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Passed pets reset successfully",
      data: result,
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
      message: "Connection request declined successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getMatches = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const matches = await getUserMatches(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Matches retrieved successfully",
      data: { matches },
    });
  } catch (error) {
    next(error);
  }
};

export const getMatchChatHandler = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    if (!id || typeof id !== "string") {
      return next(new AppError("Match id is required", 400));
    }

    const chat = await getMatchChat(req.user.id, id.trim());

    sendSuccess(res, {
      statusCode: 200,
      message: "Chat session retrieved successfully",
      data: chat,
    });
  } catch (error) {
    next(error);
  }
};

export const unmatchHandler = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    if (!id || typeof id !== "string") {
      return next(new AppError("Match id is required", 400));
    }

    const result = await unmatchMatch(req.user.id, id.trim());

    sendSuccess(res, {
      statusCode: 200,
      message: "Match ended successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

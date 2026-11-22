import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  registerSeller,
  getSellerStatusByUserId,
  resubmitSellerApplication,
  forgotPassword,
  getSellerDashboardStats,
} from "./sellers.service.ts";
import { validateSellerRegistration } from "./sellers.validation.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const register = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedInput = validateSellerRegistration(req.body);
    const result = await registerSeller(validatedInput);

    sendSuccess(res, {
      statusCode: 201,
      message: result.message,
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
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await getSellerStatusByUserId(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller application status retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const resubmit = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await resubmitSellerApplication(req.user.id, req.body);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller application resubmitted successfully. It is now under review.",
      data: { store: result },
    });
  } catch (error) {
    next(error);
  }
};

export const requestPasswordReset = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { email } = req.body;
    const result = await forgotPassword(email);

    sendSuccess(res, {
      statusCode: 200,
      message: result.message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getDashboard = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await getSellerDashboardStats(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller dashboard metrics retrieved",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

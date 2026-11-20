import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  getActivationSummary,
  initiateSlotCheckout,
  verifyAndGrantSlots,
  revokeEntitlement,
} from "./slots.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getSummary = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const summary = await getActivationSummary(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Activation summary retrieved successfully",
      data: summary,
    });
  } catch (error) {
    next(error);
  }
};

export const postCheckout = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { quantity, gateway } = req.body;
    if (!quantity || typeof quantity !== "number") {
      return next(new AppError("Field 'quantity' (number) is required", 400));
    }

    const checkoutData = await initiateSlotCheckout({
      userId: req.user.id,
      quantity,
      gateway: typeof gateway === "string" ? gateway : "esewa",
    });

    sendSuccess(res, {
      statusCode: 201,
      message: "Checkout initiated successfully",
      data: checkoutData,
    });
  } catch (error) {
    next(error);
  }
};

export const postVerifyPayment = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { paymentId, transactionId, gatewayPayload } = req.body;
    if (!paymentId || typeof paymentId !== "string") {
      return next(new AppError("paymentId is required", 400));
    }

    const result = await verifyAndGrantSlots({
      paymentId: paymentId.trim(),
      transactionId: typeof transactionId === "string" ? transactionId.trim() : undefined,
      gatewayPayload,
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

export const adminRevokeSlot = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const entitlementId = req.params.id as string;
    const { reason } = req.body;

    const result = await revokeEntitlement({
      adminUserId: req.user.id,
      entitlementId,
      reason,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Entitlement revoked successfully",
      data: { entitlement: result },
    });
  } catch (error) {
    next(error);
  }
};

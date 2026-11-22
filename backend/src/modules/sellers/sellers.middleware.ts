import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import prisma from "../../config/db.ts";
import { Role, StoreStatus } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";

/**
 * Ensures the authenticated user is an APPROVED seller.
 * Rejects with clear status codes and messages if:
 * - Unauthenticated (401)
 * - Deactivated (403)
 * - Pending application (403 with specific code)
 * - Rejected application (403 with specific code)
 * - Suspended (403 with specific code)
 */
export const requireApprovedSeller = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    if (!req.user.isActive) {
      return next(
        new AppError("Account has been suspended. Please contact platform administration.", 403)
      );
    }

    if (req.user.role !== Role.SELLER && req.user.role !== Role.ADMIN) {
      return next(
        new AppError("Access denied. Only registered sellers can access the seller dashboard.", 403)
      );
    }

    // Check store approval status
    const store = await prisma.store.findUnique({
      where: { userId: req.user.id },
    });

    if (!store) {
      return next(
        new AppError("No seller store profile found. Please register as a seller first.", 404)
      );
    }

    if (store.status === StoreStatus.PENDING) {
      return next(
        new AppError(
          "Your seller application is currently pending admin review. You will be able to access the dashboard once approved.",
          403
        )
      );
    }

    if (store.status === StoreStatus.REJECTED) {
      return next(
        new AppError(
          `Your seller application was rejected${store.rejectionReason ? `: ${store.rejectionReason}` : ""}. You may resubmit your application.`,
          403
        )
      );
    }

    if (store.status === StoreStatus.SUSPENDED) {
      return next(
        new AppError("Your store has been suspended by administration. Please contact support.", 403)
      );
    }

    next();
  } catch (err) {
    next(err);
  }
};

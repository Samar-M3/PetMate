import type { Request, Response, NextFunction } from "express";
import { firebaseAuth } from "../config/firebase.ts";
import prisma from "../config/db.ts";
import { AppError } from "./errorHandler.ts";
import type { DecodedIdToken } from "firebase-admin/auth";
import { Role, type User, type Profile } from "../generated/prisma/client.ts";

export { Role };

export interface AuthenticatedUser extends User {
  profile?: Profile | null;
}

export interface AuthenticatedRequest extends Request {
  firebaseUid?: string;
  firebaseUser?: DecodedIdToken;
  user?: AuthenticatedUser;
}

declare global {
  namespace Express {
    interface Request {
      firebaseUid?: string;
      firebaseUser?: DecodedIdToken;
      user?: AuthenticatedUser;
    }
  }
}

/**
 * Verifies Firebase ID token and loads the PostgreSQL user record.
 * Rejects deactivated accounts with 403.
 */
export const authenticateFirebase = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return next(
        new AppError("Authorization token is required (Bearer <token>)", 401)
      );
    }

    const token = authHeader.split(" ")[1];
    let decodedToken: DecodedIdToken;

    try {
      decodedToken = await firebaseAuth.verifyIdToken(token);
    } catch (err: any) {
      return next(
        new AppError(
          `Invalid or expired Firebase authentication token: ${err.message}`,
          401
        )
      );
    }

    req.firebaseUid = decodedToken.uid;
    req.firebaseUser = decodedToken;

    // Load PostgreSQL user — role comes from DB on every request
    const user = await prisma.user.findUnique({
      where: { firebaseUid: decodedToken.uid },
      include: { profile: true },
    });

    if (user) {
      if (!user.isActive) {
        return next(
          new AppError(
            "Account has been deactivated. Please contact support.",
            403
          )
        );
      }
      req.user = user;
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Rejects requests where the PostgreSQL user record doesn't exist yet
 * (i.e. /users/initialize hasn't been called).
 */
export const requireInitializedUser = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void => {
  if (!req.user) {
    return next(
      new AppError(
        "User profile has not been initialized. Please complete registration initialization first.",
        403
      )
    );
  }
  if (!req.user.isActive) {
    return next(
      new AppError("Account has been deactivated. Please contact support.", 403)
    );
  }
  next();
};

/**
 * Role-based access control middleware.
 * Pass the allowed roles explicitly — e.g. requireRole(Role.PET_OWNER, Role.ADMIN).
 */
export const requireRole = (...allowedRoles: Role[]) => {
  return (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): void => {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }
    if (!req.user.isActive) {
      return next(
        new AppError(
          "Account has been deactivated. Please contact support.",
          403
        )
      );
    }
    if (!allowedRoles.includes(req.user.role)) {
      return next(
        new AppError("Access forbidden: insufficient permissions", 403)
      );
    }
    next();
  };
};

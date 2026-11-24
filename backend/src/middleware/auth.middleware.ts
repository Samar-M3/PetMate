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
 * Supports checking token revocation.
 */
export const createAuthenticateFirebase = (options: { checkRevoked?: boolean } = {}) => {
  return async (
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
        try {
          decodedToken = await firebaseAuth.verifyIdToken(token, options.checkRevoked ?? false);
        } catch (checkErr: any) {
          if (options.checkRevoked && (checkErr.message?.includes("invalid_grant") || checkErr.message?.includes("Credential") || checkErr.message?.includes("OAuth2"))) {
            console.warn("⚠️ checkRevoked verification failed due to credential issue. Falling back to standard public key verification.");
            decodedToken = await firebaseAuth.verifyIdToken(token, false);
          } else {
            throw checkErr;
          }
        }
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
};

export const authenticateFirebase = createAuthenticateFirebase({ checkRevoked: false });
export const authenticateAdmin = createAuthenticateFirebase({ checkRevoked: true });

/**
 * Optional Firebase authentication.
 * If Bearer token is provided, validates it and populates req.firebaseUser and req.user.
 * If no token is provided, continues cleanly without throwing a 401 error.
 */
export const authenticateOptionalFirebase = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return next();
    }

    const token = authHeader.split(" ")[1];
    if (!token || token === "null" || token === "undefined") {
      return next();
    }

    try {
      const decodedToken = await firebaseAuth.verifyIdToken(token, false);
      req.firebaseUid = decodedToken.uid;
      req.firebaseUser = decodedToken;

      const user = await prisma.user.findUnique({
        where: { firebaseUid: decodedToken.uid },
        include: { profile: true },
      });

      if (user && user.isActive) {
        req.user = user;
      }
    } catch (_) {
      // Optional authentication ignores invalid tokens
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

import type { Request, Response, NextFunction } from "express";
import { firebaseAuth } from "../config/firebase.ts";
import prisma from "../config/db.ts";
import { AppError } from "./errorHandler.ts";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { User, Profile } from "../generated/prisma/client.ts";

export interface AuthenticatedUser extends User {
  profile?: Profile | null;
}

export interface AuthenticatedRequest extends Request {
  firebaseUid?: string;
  firebaseUser?: DecodedIdToken;
  user?: AuthenticatedUser;
}

export const authenticateFirebase = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.warn("[AuthMiddleware] ⚠️ Request missing Bearer authorization token header");
      return next(new AppError("Authorization token is required (Bearer <token>)", 401));
    }

    const token = authHeader.split(" ")[1];
    let decodedToken: DecodedIdToken;

    try {
      console.log("[AuthMiddleware] 🔑 Verifying Firebase ID token...");
      decodedToken = await firebaseAuth.verifyIdToken(token);
      console.log(`[AuthMiddleware] ✅ Verified token for UID: ${decodedToken.uid} (email: ${decodedToken.email})`);
    } catch (err: any) {
      console.error("[AuthMiddleware] ❌ Firebase token verification failed:", err.message);
      return next(new AppError(`Invalid or expired Firebase authentication token: ${err.message}`, 401));
    }

    req.firebaseUid = decodedToken.uid;
    req.firebaseUser = decodedToken;

    // Look up existing PostgreSQL user record
    console.log(`[AuthMiddleware] 🔍 Checking PostgreSQL for user: ${decodedToken.uid}`);
    const user = await prisma.user.findUnique({
      where: { firebaseUid: decodedToken.uid },
      include: { profile: true },
    });

    if (user) {
      console.log(`[AuthMiddleware] 👤 PostgreSQL user record found: ID ${user.id}`);
      req.user = user;
    } else {
      console.log(`[AuthMiddleware] ℹ️ User ${decodedToken.uid} not yet in PostgreSQL`);
    }

    next();
  } catch (error) {
    console.error("[AuthMiddleware] ❌ Unexpected error in auth middleware:", error);
    next(error);
  }
};

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
  next();
};

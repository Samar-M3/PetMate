import { Router, type Response, type NextFunction } from "express";
import {
  authenticateFirebase,
  requireInitializedUser,
  requirePasswordSetupComplete,
  type AuthenticatedRequest,
} from "../../middleware/auth.middleware.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import {
  getNearbyOwnersController,
  updateLocationController,
  updateLocationVisibilityController,
} from "./owners.controller.ts";

// Sliding-window in-memory rate limiter for location updates (max 15 updates/min per user)
const LOCATION_WINDOW_MS = 60 * 1000;
const LOCATION_MAX_REQUESTS = 15;
const locationUpdateBuckets = new Map<string, number[]>();

const rateLimitLocationUpdates = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void => {
  const key = req.user?.id || req.ip || "anonymous";
  const now = Date.now();
  const timestamps = (locationUpdateBuckets.get(key) || []).filter(
    (t) => now - t < LOCATION_WINDOW_MS
  );

  if (timestamps.length >= LOCATION_MAX_REQUESTS) {
    const retryAfterSec = Math.ceil(
      (LOCATION_WINDOW_MS - (now - timestamps[0])) / 1000
    );
    res.setHeader("Retry-After", String(Math.max(1, retryAfterSec)));
    return next(
      new AppError(
        "Too many location updates. Please wait a moment before trying again.",
        429
      )
    );
  }

  timestamps.push(now);
  locationUpdateBuckets.set(key, timestamps);
  next();
};

const router = Router();

router.use(
  authenticateFirebase,
  requireInitializedUser,
  requirePasswordSetupComplete
);

router.post("/location", rateLimitLocationUpdates, updateLocationController);
router.get("/nearby", getNearbyOwnersController);
router.patch("/location-visibility", updateLocationVisibilityController);

export default router;

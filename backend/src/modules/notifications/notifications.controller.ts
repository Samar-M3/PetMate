import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { NotificationService } from "../../services/notification.service.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";

// Simple in-memory rate limiter for device registrations (30 per hour per user)
const deviceRegisterLimits = new Map<string, { count: number; resetAt: number }>();

function checkDeviceRateLimit(userId: string): void {
  const now = Date.now();
  const entry = deviceRegisterLimits.get(userId);
  if (!entry || now > entry.resetAt) {
    deviceRegisterLimits.set(userId, { count: 1, resetAt: now + 3600_000 });
    return;
  }
  if (entry.count >= 30) {
    throw new AppError("Too many device registration requests. Please try again later.", 429);
  }
  entry.count++;
}

export async function registerDeviceController(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = req.user;
    if (!user) {
      throw new AppError("Authentication required", 401);
    }

    checkDeviceRateLimit(user.id);

    const { token, platform, appVersion, locale } = req.body;
    if (!token || typeof token !== "string" || token.trim().length < 10 || token.length > 4096) {
      throw new AppError("A valid device token string is required", 400);
    }

    const allowedPlatforms = ["android", "ios", "web"];
    if (platform && (!allowedPlatforms.includes(String(platform).toLowerCase()))) {
      throw new AppError("Invalid platform. Must be android, ios, or web", 400);
    }

    const allowedLocales = ["en", "ne"];
    if (locale && (!allowedLocales.includes(String(locale).toLowerCase()))) {
      throw new AppError("Invalid locale. Must be en or ne", 400);
    }

    if (appVersion && typeof appVersion !== "string") {
      throw new AppError("appVersion must be a string", 400);
    }

    const deviceToken = await NotificationService.registerDeviceToken(user.id, {
      token,
      platform,
      appVersion: appVersion ? String(appVersion).slice(0, 50) : undefined,
      locale,
    });

    sendSuccess(res, {
      statusCode: 201,
      message: "Device token registered successfully",
      data: {
        id: deviceToken.id,
        platform: deviceToken.platform,
        locale: deviceToken.locale,
        appVersion: deviceToken.appVersion,
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function deleteDeviceController(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = req.user;
    if (!user) {
      throw new AppError("Authentication required", 401);
    }

    const token = req.params.token;
    if (!token || typeof token !== "string") {
      throw new AppError("Device token parameter is required", 400);
    }

    const count = await NotificationService.removeDeviceToken(user.id, token);
    sendSuccess(res, {
      message: count > 0 ? "Device token removed successfully" : "Device token not found",
      data: { removed: count > 0 },
    });
  } catch (error) {
    next(error);
  }
}

export async function getPreferencesController(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = req.user;
    if (!user) {
      throw new AppError("Authentication required", 401);
    }

    const preferences = await NotificationService.getPreferences(user.id);
    sendSuccess(res, {
      message: "Notification preferences retrieved successfully",
      data: preferences,
    });
  } catch (error) {
    next(error);
  }
}

export async function updatePreferencesController(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = req.user;
    if (!user) {
      throw new AppError("Authentication required", 401);
    }

    const body = req.body;
    if (!body || typeof body !== "object") {
      throw new AppError("Request body must be a JSON object", 400);
    }

    // Strict allowlist validation
    const allowedKeys = ["messages", "requests", "matches", "orders", "system", "showPreviews"];
    const updates: Record<string, boolean> = {};

    for (const key of Object.keys(body)) {
      if (!allowedKeys.includes(key)) {
        throw new AppError(`Unexpected field in request body: ${key}`, 400);
      }
      if (typeof body[key] !== "boolean") {
        throw new AppError(`Field '${key}' must be a boolean`, 400);
      }
      updates[key] = body[key];
    }

    if (Object.keys(updates).length === 0) {
      throw new AppError("At least one preference setting must be provided to update", 400);
    }

    const updated = await NotificationService.updatePreferences(user.id, updates);
    sendSuccess(res, {
      message: "Notification preferences updated successfully",
      data: updated,
    });
  } catch (error) {
    next(error);
  }
}

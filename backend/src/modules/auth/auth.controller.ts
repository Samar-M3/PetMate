import type { Request, Response, NextFunction } from "express";
import { registerUser, loginUser, getCurrentUserProfile } from "./auth.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";

export const register = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const result = await registerUser(req.body);
    sendSuccess(res, {
      statusCode: 201,
      message: "User registered successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const result = await loginUser(req.body);
    sendSuccess(res, {
      statusCode: 200,
      message: "Login successful",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getProfile = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    if (!req.user) {
      return next(new Error("User not found in authenticated request"));
    }
    const profile = await getCurrentUserProfile(req.user.id);
    sendSuccess(res, {
      statusCode: 200,
      message: "User profile fetched successfully",
      data: { user: profile },
    });
  } catch (error) {
    next(error);
  }
};

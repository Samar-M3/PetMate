import type { Request, Response, NextFunction } from "express";
import { registerPetOwner, loginWithEmailPassword } from "./auth.service.ts";
import { validateRegister, validateLogin } from "./auth.validation.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";

export const register = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedData = validateRegister(req.body);
    const result = await registerPetOwner(validatedData);

    sendSuccess(res, {
      statusCode: 201,
      message: "Registration started successfully. Please complete your pet profile.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedData = validateLogin(req.body);
    const result = await loginWithEmailPassword(validatedData);

    sendSuccess(res, {
      statusCode: 200,
      message: "Login successful",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

import type { Request, Response, NextFunction } from "express";
import { sendError } from "../utils/apiResponse.ts";

export class AppError extends Error {
  public statusCode: number;
  public errors: string[];

  constructor(message: string, statusCode = 400, errors: string[] = []) {
    super(message);
    this.statusCode = statusCode;
    this.errors = errors;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  next: NextFunction
): Response => {
  console.error("[Error Handler]:", err);

  const statusCode = "statusCode" in err && typeof err.statusCode === "number" ? err.statusCode : 500;
  const message = err.message || "Internal server error";
  const errors = "errors" in err && Array.isArray(err.errors) && err.errors.length > 0 ? err.errors : [message];

  return sendError(res, {
    statusCode,
    message,
    errors,
  });
};

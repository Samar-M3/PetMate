import type { Response } from "express";

interface SuccessResponseOptions<T = unknown> {
  statusCode?: number;
  message?: string;
  data?: T;
}

interface ErrorResponseOptions {
  statusCode?: number;
  message?: string;
  errors?: string[];
}

export const sendSuccess = <T>(
  res: Response,
  { statusCode = 200, message = "Operation completed successfully", data = {} as T }: SuccessResponseOptions<T> = {}
): Response => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
  });
};

export const sendError = (
  res: Response,
  { statusCode = 500, message = "Internal server error", errors = [] }: ErrorResponseOptions = {}
): Response => {
  return res.status(statusCode).json({
    success: false,
    message,
    errors,
  });
};

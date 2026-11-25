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

  let statusCode = "statusCode" in err && typeof err.statusCode === "number" ? err.statusCode : 500;
  let message = err.message || "Internal server error";
  let errors = "errors" in err && Array.isArray(err.errors) && err.errors.length > 0 ? err.errors : [message];

  // Map PostgreSQL / Prisma check constraint errors to user-friendly messages
  const errStr = (err.message || "") + " " + JSON.stringify(err);
  if (
    errStr.includes("products_discounted_price_valid_check") ||
    (errStr.includes("23514") && errStr.includes("discounted_price"))
  ) {
    statusCode = 400;
    message = "Sale price must be strictly greater than 0 and less than regular price.";
    errors = [message];
  } else if (
    errStr.includes("products_base_price_positive_check") ||
    (errStr.includes("23514") && errStr.includes("base_price"))
  ) {
    statusCode = 400;
    message = "Regular price must be greater than 0.";
    errors = [message];
  } else if (
    errStr.includes("products_available_stock_nonnegative_check") ||
    (errStr.includes("23514") && errStr.includes("available_stock"))
  ) {
    statusCode = 400;
    message = "Available stock cannot be negative.";
    errors = [message];
  } else if (errStr.includes("P2002")) {
    statusCode = 409;
    message = "A record with this unique value already exists.";
    errors = [message];
  }

  return sendError(res, {
    statusCode,
    message,
    errors,
  });
};

import { sendError } from "../utils/apiResponse.js";

export class AppError extends Error {
  constructor(message, statusCode = 400, errors = []) {
    super(message);
    this.statusCode = statusCode;
    this.errors = errors;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (err, req, res, next) => {
  console.error("[Error Handler]:", err);

  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal server error";
  const errors = err.errors && err.errors.length > 0 ? err.errors : [message];

  return sendError(res, {
    statusCode,
    message,
    errors,
  });
};

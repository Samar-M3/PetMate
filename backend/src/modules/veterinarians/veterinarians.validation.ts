import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

const passwordSchema = Joi.string()
  .min(8)
  .max(128)
  .pattern(/^(?=.*[A-Za-z])(?=.*\d).+$/)
  .required()
  .messages({
    "string.min": "Password must be at least 8 characters long",
    "string.max": "Password must be at most 128 characters long",
    "string.pattern.base": "Password must contain at least one letter and one number",
    "any.required": "Password is required",
  });

export const createVeterinarianAccountSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100).required(),
  email: Joi.string()
    .trim()
    .email({ tlds: { allow: false } })
    .max(254)
    .required(),
  password: passwordSchema,
  licenseNumber: Joi.string().trim().max(100).allow("").optional(),
  clinicName: Joi.string().trim().min(2).max(150).required(),
  specialty: Joi.string().trim().min(2).max(100).required(),
  address: Joi.string().trim().min(2).max(255).required(),
  fee: Joi.number().integer().min(0).max(1000000).default(500),
  isAcceptingBookings: Joi.boolean().default(true),
}).unknown(false);

export const initialVeterinarianPasswordSchema = Joi.object({
  newPassword: passwordSchema,
}).unknown(false);

export interface CreateVeterinarianAccountInput {
  name: string;
  email: string;
  password: string;
  licenseNumber?: string;
  clinicName: string;
  specialty: string;
  address: string;
  fee: number;
  isAcceptingBookings: boolean;
}

export function validateCreateVeterinarianAccount(
  input: unknown,
): CreateVeterinarianAccountInput {
  return validate<CreateVeterinarianAccountInput>(
    input,
    createVeterinarianAccountSchema,
  );
}

export function validateInitialVeterinarianPassword(input: unknown): string {
  const result = validate<{ newPassword: string }>(
    input,
    initialVeterinarianPasswordSchema,
  );
  return result.newPassword;
}

function validate<T>(input: unknown, schema: Joi.ObjectSchema): T {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new AppError("Request body must be an object", 400);
  }

  const { error, value } = schema.validate(input, {
    abortEarly: false,
    convert: true,
    stripUnknown: false,
  });
  if (error) {
    throw new AppError(error.details.map((detail) => detail.message).join(", "), 400);
  }

  if (typeof value.email === "string") value.email = value.email.toLowerCase();
  return value as T;
}

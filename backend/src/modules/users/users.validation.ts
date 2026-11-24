import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface InitializeUserInput {
  phoneNumber?: string;
}

export const initializeUserSchema = Joi.object({
  phoneNumber: Joi.string()
    .trim()
    .pattern(/^\d{10}$/)
    .messages({
      "string.pattern.base": "Phone number must be exactly 10 digits",
      "string.empty": "Phone number cannot be empty",
    }),
});

export const updateOwnerProfileSchema = Joi.object({
  fullName: Joi.string().trim().min(2).max(100).allow(null, ""),
  profilePictureUrl: Joi.string().uri().allow(null, ""),
  imageUrl: Joi.string().uri().allow(null, ""),
  imagePublicId: Joi.string().allow(null, ""),
  location: Joi.string().trim().max(100).allow(null, ""),
  area: Joi.string().trim().max(100).allow(null, ""),
  bio: Joi.string().trim().max(500).allow(null, ""),
  phoneNumber: Joi.string()
    .trim()
    .pattern(/^\d{10}$/)
    .allow(null, "")
    .messages({
      "string.pattern.base": "Phone number must be exactly 10 digits",
    }),
  onboardingCompleted: Joi.boolean(),
});

export function validateInitializeUser(data: unknown): InitializeUserInput {
  const { error, value } = initializeUserSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  return value as InitializeUserInput;
}

export function validateUpdateOwnerProfile(data: unknown) {
  const { error, value } = updateOwnerProfileSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  return value;
}

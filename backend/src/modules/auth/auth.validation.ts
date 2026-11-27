import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface RegisterDTO {
  email: string;
  password: string;
  fullName: string;
  displayName?: string;
  phoneNumber: string;
  city: string;
  district: string;
  avatarUrl?: string;
  avatarPublicId?: string;
  termsAccepted: boolean;
  role?: string;
}

export interface LoginDTO {
  email: string;
  password: string;
}

const registerSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  password: Joi.string().min(8).required().messages({
    "string.min": "Password must be at least 8 characters",
    "any.required": "Password is required",
  }),
  fullName: Joi.string().trim().min(2).max(100).required().messages({
    "string.min": "Full name must be at least 2 characters",
    "any.required": "Full name is required",
  }),
  displayName: Joi.string().trim().max(100).optional().allow(""),
  phoneNumber: Joi.string()
    .trim()
    .pattern(/^(?:98|97)\d{8}$|^\d{10}$/)
    .required()
    .messages({
      "string.pattern.base": "Phone number must be a valid 10-digit Nepal mobile number (e.g. 98XXXXXXXX)",
      "any.required": "Phone number is required",
    }),
  city: Joi.string().trim().required().messages({
    "any.required": "City is required",
  }),
  district: Joi.string().trim().required().messages({
    "any.required": "District is required",
  }),
  avatarUrl: Joi.string().uri().optional().allow("", null),
  avatarPublicId: Joi.string().optional().allow("", null),
  termsAccepted: Joi.boolean().valid(true).required().messages({
    "any.only": "You must be 18+ and accept the Terms and Privacy Policy",
    "any.required": "Terms and Privacy Policy agreement is required",
  }),
  role: Joi.string().valid("PET_OWNER", "SELLER", "VETERINARIAN").default("PET_OWNER"),
});

const loginSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  password: Joi.string().required().messages({
    "any.required": "Password is required",
  }),
});

export const validateRegister = (data: unknown): RegisterDTO => {
  const { error, value } = registerSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const messages = error.details.map((d) => d.message.replace(/"/g, ""));
    throw new AppError("Registration validation failed", 400, messages);
  }

  return value;
};

export const validateLogin = (data: unknown): LoginDTO => {
  const { error, value } = loginSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const messages = error.details.map((d) => d.message.replace(/"/g, ""));
    throw new AppError("Login validation failed", 400, messages);
  }

  return value;
};

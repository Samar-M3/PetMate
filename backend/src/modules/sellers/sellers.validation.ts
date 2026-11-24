import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface RegisterSellerInput {
  fullName: string;
  email: string;
  phoneNumber: string;
  password: string;
  confirmPassword?: string;
  storeName: string;
  businessType?: string;
  description?: string;
  businessAddress: string;
  city: string;
  province: string;
  postalCode: string;
  registrationDocUrl?: string;
  identityDocUrl?: string;
  termsAccepted: boolean;
}

export const sellerRegistrationSchema = Joi.object({
  fullName: Joi.string().trim().min(2).max(100).required().messages({
    "string.empty": "Full name is required",
    "string.min": "Full name must be at least 2 characters",
    "any.required": "Full name is required",
  }),
  email: Joi.string()
    .trim()
    .email({ tlds: { allow: false } })
    .pattern(/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)
    .required()
    .messages({
      "string.empty": "Email is required",
      "string.email": "A valid email address is required",
      "string.pattern.base": "A valid email address is required",
      "any.required": "Email is required",
    }),
  phoneNumber: Joi.string()
    .trim()
    .pattern(/^\d{10}$/)
    .required()
    .messages({
      "string.empty": "Phone number is required",
      "string.pattern.base": "Phone number must be exactly 10 digits",
      "any.required": "Phone number is required",
    }),
  password: Joi.string()
    .min(6)
    .max(128)
    .pattern(/^(?=.*[A-Za-z])(?=.*\d)/)
    .required()
    .messages({
      "string.empty": "Password is required",
      "string.min": "Password must be at least 6 characters long",
      "string.pattern.base": "Password must contain at least one letter and one number",
      "any.required": "Password is required",
    }),
  confirmPassword: Joi.string()
    .valid(Joi.ref("password"))
    .optional()
    .messages({
      "any.only": "Confirm password does not match password",
    }),
  storeName: Joi.string().trim().min(2).max(150).required().messages({
    "string.empty": "Store name is required",
    "string.min": "Store name must be at least 2 characters",
    "any.required": "Store name is required",
  }),
  businessType: Joi.string()
    .valid("INDIVIDUAL", "REGISTERED_BUSINESS")
    .default("INDIVIDUAL"),
  description: Joi.string().trim().max(1000).allow(null, "").optional(),
  businessAddress: Joi.string().trim().min(2).max(255).required().messages({
    "string.empty": "Business address is required",
    "any.required": "Business address is required",
  }),
  city: Joi.string().trim().min(2).max(100).required().messages({
    "string.empty": "City is required",
    "any.required": "City is required",
  }),
  province: Joi.string().trim().min(2).max(100).required().messages({
    "string.empty": "Province is required",
    "any.required": "Province is required",
  }),
  postalCode: Joi.string().trim().min(2).max(20).required().messages({
    "string.empty": "Postal code is required",
    "any.required": "Postal code is required",
  }),
  registrationDocUrl: Joi.string().uri().allow(null, "").optional(),
  identityDocUrl: Joi.string().uri().allow(null, "").optional(),
  termsAccepted: Joi.boolean().truthy("true", 1).required().messages({
    "any.required": "You must accept the terms and conditions and privacy policy",
    "boolean.base": "You must accept the terms and conditions and privacy policy",
  }),
  privacyAccepted: Joi.boolean().truthy("true", 1).optional(),
});

export function validateSellerRegistration(data: unknown): RegisterSellerInput {
  if (!data || typeof data !== "object") {
    throw new AppError("Request body must be an object", 400);
  }

  const { error, value } = sellerRegistrationSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  return {
    fullName: value.fullName,
    email: value.email.toLowerCase(),
    phoneNumber: value.phoneNumber,
    password: value.password,
    confirmPassword: value.confirmPassword,
    storeName: value.storeName,
    businessType: value.businessType || "INDIVIDUAL",
    description: value.description,
    businessAddress: value.businessAddress,
    city: value.city,
    province: value.province,
    postalCode: value.postalCode,
    registrationDocUrl: value.registrationDocUrl,
    identityDocUrl: value.identityDocUrl,
    termsAccepted: true,
  };
}

import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface UpdateProfileMeInput {
  displayName: string;
  phoneNumber?: string | null;
  avatarUrl?: string | null;
  avatarPublicId?: string | null;
  city: string;
  district: string;
  termsAccepted?: boolean;
}

const updateProfileMeSchema = Joi.object({
  displayName: Joi.string().trim().min(2).max(100),
  fullName: Joi.string().trim().min(2).max(100),
  phoneNumber: Joi.string()
    .trim()
    .pattern(/^(?:98|97)\d{8}$|^\d{10}$/)
    .allow("", null)
    .optional(),
  avatarUrl: Joi.string().uri().allow("", null).optional(),
  avatarPublicId: Joi.string().trim().allow("", null).optional(),
  city: Joi.string().trim().min(2).max(80).required().messages({
    "string.empty": "City or district is required",
    "any.required": "City or district is required",
  }),
  district: Joi.string().trim().min(2).max(80).optional().allow("", null),
  termsAccepted: Joi.boolean().optional(),
})
  .or("displayName", "fullName")
  .messages({
    "object.missing": "Full name is required",
  });

export function validateUpdateProfileMe(body: unknown): UpdateProfileMeInput {
  const { error, value } = updateProfileMeSchema.validate(body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const details = error.details.map((d) => d.message.replace(/"/g, ""));
    throw new AppError(details[0] || "Validation failed", 400, details);
  }

  const displayName = (value.displayName || value.fullName || "").trim();
  const city = (value.city || "").trim();
  const district = (value.district || value.city || "").trim();

  return {
    displayName,
    phoneNumber: value.phoneNumber ? String(value.phoneNumber).trim() : null,
    avatarUrl: value.avatarUrl ? String(value.avatarUrl).trim() : null,
    avatarPublicId: value.avatarPublicId ? String(value.avatarPublicId).trim() : null,
    city,
    district,
    termsAccepted: typeof value.termsAccepted === "boolean" ? value.termsAccepted : undefined,
  };
}

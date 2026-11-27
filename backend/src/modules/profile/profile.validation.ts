import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface UpdateProfileMeInput {
  displayName: string;
  avatarUrl?: string | null;
  avatarPublicId?: string | null;
  city: string;
  district: string;
}

const updateProfileMeSchema = Joi.object({
  displayName: Joi.string().trim().min(2).max(100),
  fullName: Joi.string().trim().min(2).max(100),
  avatarUrl: Joi.string().uri().allow("", null).optional(),
  avatarPublicId: Joi.string().trim().allow("", null).optional(),
  city: Joi.string().trim().min(2).max(80).required().messages({
    "string.empty": "City or district is required",
    "any.required": "City or district is required",
  }),
  district: Joi.string().trim().min(2).max(80).optional().allow("", null),
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
    avatarUrl: value.avatarUrl ? String(value.avatarUrl).trim() : null,
    avatarPublicId: value.avatarPublicId ? String(value.avatarPublicId).trim() : null,
    city,
    district,
  };
}

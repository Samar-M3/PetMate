import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";

export interface UpdateLocationInput {
  latitude: number;
  longitude: number;
  area?: string | null;
  locationEnabled?: boolean;
}

export interface NearbyQueryInput {
  radius: number;
  page: number;
  limit: number;
}

export interface UpdateVisibilityInput {
  locationEnabled: boolean;
}

const updateLocationSchema = Joi.object({
  latitude: Joi.number().min(-90).max(90).required().messages({
    "number.base": "Latitude must be a valid number",
    "number.min": "Latitude must be between -90 and 90",
    "number.max": "Latitude must be between -90 and 90",
    "any.required": "Latitude is required",
  }),
  longitude: Joi.number().min(-180).max(180).required().messages({
    "number.base": "Longitude must be a valid number",
    "number.min": "Longitude must be between -180 and 180",
    "number.max": "Longitude must be between -180 and 180",
    "any.required": "Longitude is required",
  }),
  area: Joi.string().trim().max(120).allow(null, ""),
  locationEnabled: Joi.boolean(),
});

const nearbyQuerySchema = Joi.object({
  radius: Joi.number().valid(5, 10, 20).default(10).messages({
    "any.only": "Radius must be 5, 10, or 20 km",
    "number.base": "Radius must be a valid number",
  }),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(50).default(20),
});

const updateVisibilitySchema = Joi.object({
  locationEnabled: Joi.boolean().required().messages({
    "boolean.base": "locationEnabled must be a boolean",
    "any.required": "locationEnabled is required",
  }),
});

export function validateUpdateLocation(data: unknown): UpdateLocationInput {
  const { error, value } = updateLocationSchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  const parsed = value as UpdateLocationInput;
  if (!Number.isFinite(parsed.latitude) || !Number.isFinite(parsed.longitude)) {
    throw new AppError("Coordinates must be finite numbers", 400);
  }
  if (parsed.latitude === 0 && parsed.longitude === 0) {
    throw new AppError("Invalid coordinates (0, 0)", 400);
  }

  return parsed;
}

export function validateNearbyQuery(query: unknown): NearbyQueryInput {
  const { error, value } = nearbyQuerySchema.validate(query, {
    abortEarly: false,
    stripUnknown: true,
    convert: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  return value as NearbyQueryInput;
}

export function validateUpdateVisibility(data: unknown): UpdateVisibilityInput {
  const { error, value } = updateVisibilitySchema.validate(data, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const message = error.details.map((d) => d.message).join(", ");
    throw new AppError(message, 400);
  }

  return value as UpdateVisibilityInput;
}

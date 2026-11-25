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

export interface CreateProductInput {
  name: string;
  sku?: string;
  brand?: string;
  description?: string;
  shortDescription?: string;
  basePrice: number;
  discountedPrice?: number;
  costPrice?: number;
  availableStock?: number;
  lowStockThreshold?: number;
  status?: "ACTIVE" | "DRAFT";
  isFeatured?: boolean;
  categoryId?: string;
  shippingWeight?: number;
  packageDimensions?: string;
  specifications?: Record<string, any>;
  imageUrls?: string[];
}

export function validateCreateProduct(data: any): CreateProductInput {
  if (!data || typeof data !== "object") {
    throw new AppError("Invalid product data", 400);
  }
  const name = typeof data.name === "string" ? data.name.trim() : "";
  if (!name || name.length < 2) {
    throw new AppError("Product name is required (minimum 2 characters)", 400);
  }

  const basePrice = Number(data.basePrice);
  if (isNaN(basePrice) || basePrice <= 0) {
    throw new AppError("A valid regular price greater than 0 is required", 400);
  }

  let discountedPrice: number | undefined;
  if (
    data.discountedPrice !== undefined &&
    data.discountedPrice !== null &&
    data.discountedPrice !== ""
  ) {
    const parsed = Number(data.discountedPrice);
    if (isNaN(parsed)) {
      throw new AppError("Discounted price must be a valid number", 400);
    }
    if (parsed < 0) {
      throw new AppError("Discounted price cannot be negative", 400);
    }
    if (parsed === 0) {
      // 0 means no discount -> store as NULL in database
      discountedPrice = undefined;
    } else {
      if (parsed >= basePrice) {
        throw new AppError(
          `Discounted price (${parsed}) must be strictly less than regular price (${basePrice})`,
          400
        );
      }
      discountedPrice = parsed;
    }
  }

  let costPrice: number | undefined;
  if (data.costPrice !== undefined && data.costPrice !== null && data.costPrice !== "") {
    costPrice = Number(data.costPrice);
  }

  const availableStock = data.availableStock !== undefined && data.availableStock !== null
    ? Math.max(0, parseInt(String(data.availableStock), 10) || 0)
    : 0;

  const lowStockThreshold = data.lowStockThreshold !== undefined && data.lowStockThreshold !== null
    ? Math.max(0, parseInt(String(data.lowStockThreshold), 10) || 5)
    : 5;

  let shippingWeight: number | undefined;
  if (data.shippingWeight !== undefined && data.shippingWeight !== null && data.shippingWeight !== "") {
    const rawWeight = String(data.shippingWeight).replace(/[^0-9.]/g, "");
    const parsedWeight = parseFloat(rawWeight);
    if (!isNaN(parsedWeight) && parsedWeight > 0) {
      shippingWeight = parsedWeight;
    }
  }

  const status = data.status === "ACTIVE" ? "ACTIVE" : "DRAFT";
  const isFeatured = Boolean(data.isFeatured);

  const imageUrls = Array.isArray(data.imageUrls)
    ? data.imageUrls.filter((u: any) => typeof u === "string" && u.trim().length > 0)
    : [];

  return {
    name,
    sku: typeof data.sku === "string" ? data.sku.trim() : undefined,
    brand: typeof data.brand === "string" ? data.brand.trim() : undefined,
    description: typeof data.description === "string" ? data.description.trim() : undefined,
    shortDescription: typeof data.shortDescription === "string" ? data.shortDescription.trim() : undefined,
    basePrice,
    discountedPrice,
    costPrice,
    availableStock,
    lowStockThreshold,
    status,
    isFeatured,
    categoryId: typeof data.categoryId === "string" && data.categoryId.trim().length > 0 ? data.categoryId.trim() : undefined,
    shippingWeight,
    packageDimensions: typeof data.packageDimensions === "string" ? data.packageDimensions.trim() : undefined,
    specifications: typeof data.specifications === "object" && data.specifications !== null ? data.specifications : undefined,
    imageUrls,
  };
}

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

export function validateSellerRegistration(data: any): RegisterSellerInput {
  const {
    fullName,
    email,
    phoneNumber,
    password,
    confirmPassword,
    storeName,
    businessType,
    description,
    businessAddress,
    city,
    province,
    postalCode,
    registrationDocUrl,
    identityDocUrl,
    termsAccepted,
  } = data;

  if (!fullName || typeof fullName !== "string" || fullName.trim().length < 2) {
    throw new AppError("Full name is required (minimum 2 characters)", 400);
  }

  if (!email || typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    throw new AppError("A valid email address is required", 400);
  }

  if (!phoneNumber || typeof phoneNumber !== "string" || phoneNumber.trim().length < 7) {
    throw new AppError("A valid phone number is required (minimum 7 digits)", 400);
  }

  if (!password || typeof password !== "string" || password.length < 6) {
    throw new AppError("Password must be at least 6 characters long", 400);
  }

  if (confirmPassword && confirmPassword !== password) {
    throw new AppError("Confirm password does not match password", 400);
  }

  if (!storeName || typeof storeName !== "string" || storeName.trim().length < 2) {
    throw new AppError("Store name is required (minimum 2 characters)", 400);
  }

  if (!businessAddress || typeof businessAddress !== "string" || businessAddress.trim().length === 0) {
    throw new AppError("Business address is required", 400);
  }

  if (!city || typeof city !== "string" || city.trim().length === 0) {
    throw new AppError("City is required", 400);
  }

  if (!province || typeof province !== "string" || province.trim().length === 0) {
    throw new AppError("Province is required", 400);
  }

  if (!postalCode || typeof postalCode !== "string" || postalCode.trim().length === 0) {
    throw new AppError("Postal code is required", 400);
  }

  if (termsAccepted !== true && termsAccepted !== "true") {
    throw new AppError("You must accept the terms and conditions and privacy policy to register as a seller", 400);
  }

  const normalizedBusinessType =
    businessType && businessType.toUpperCase() === "REGISTERED_BUSINESS"
      ? "REGISTERED_BUSINESS"
      : "INDIVIDUAL";

  return {
    fullName: fullName.trim(),
    email: email.trim().toLowerCase(),
    phoneNumber: phoneNumber.trim(),
    password,
    storeName: storeName.trim(),
    businessType: normalizedBusinessType,
    description: description ? String(description).trim() : undefined,
    businessAddress: businessAddress.trim(),
    city: city.trim(),
    province: province.trim(),
    postalCode: postalCode.trim(),
    registrationDocUrl: registrationDocUrl ? String(registrationDocUrl).trim() : undefined,
    identityDocUrl: identityDocUrl ? String(identityDocUrl).trim() : undefined,
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

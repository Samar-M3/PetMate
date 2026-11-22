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

import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "node:crypto";
import prisma from "../../config/db.ts";
import env from "../../config/env.ts";
import { Role } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { RegisterDTO, LoginDTO } from "./auth.validation.ts";

const JWT_SECRET = process.env.JWT_SECRET || "petmate-super-secret-jwt-key-2026";

export const generateAuthToken = (user: {
  id: string;
  email: string | null;
  role: string;
  firebaseUid: string;
}) => {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
      role: user.role,
      firebaseUid: user.firebaseUid,
    },
    JWT_SECRET,
    { expiresIn: "30d" }
  );
};

export const registerPetOwner = async (data: RegisterDTO) => {
  const normalizedEmail = data.email.toLowerCase().trim();

  // Check if email already registered
  const existingUser = await prisma.user.findFirst({
    where: { email: normalizedEmail },
    include: { profile: true },
  });

  if (existingUser) {
    const isIncomplete =
      !existingUser.registrationCompleted && !existingUser.onboardingCompleted;

    if (isIncomplete) {
      throw new AppError(
        "This email is already registered with an incomplete registration. Please log in to continue.",
        409,
        ["INCOMPLETE_REGISTRATION"]
      );
    }

    throw new AppError("This email is already registered. Please log in.", 409);
  }

  // Hash password
  const passwordHash = await bcrypt.hash(data.password, 10);
  const firebaseUid = `uid_${crypto.randomUUID().replace(/-/g, "")}`;
  const displayName = data.displayName?.trim() || data.fullName.trim();

  const result = await prisma.$transaction(async (tx) => {
    // 1. Create User
    const user = await tx.user.create({
      data: {
        firebaseUid,
        email: normalizedEmail,
        phoneNumber: data.phoneNumber.trim(),
        passwordHash,
        role: Role.PET_OWNER,
        onboardingCompleted: false,
        registrationCompleted: false,
        isEmailVerified: false,
        isPhoneVerified: false,
      },
    });

    // 2. Create Profile with step 2 (Pet Profile next)
    const profile = await tx.profile.create({
      data: {
        userId: user.id,
        fullName: data.fullName.trim(),
        displayName,
        phone: data.phoneNumber.trim(),
        city: data.city.trim(),
        district: data.district.trim(),
        location: `${data.city.trim()}, ${data.district.trim()}`,
        avatarUrl: data.avatarUrl || null,
        imageUrl: data.avatarUrl || null,
        imagePublicId: data.avatarPublicId || null,
        onboardingStep: 2,
        onboardingCompleted: false,
        registrationCompleted: false,
        isEmailVerified: false,
        isPhoneVerified: false,
        termsAcceptedAt: new Date(),
      },
    });

    return { user, profile };
  });

  const token = generateAuthToken(result.user);

  return {
    token,
    user: {
      id: result.user.id,
      email: result.user.email,
      phoneNumber: result.user.phoneNumber,
      role: result.user.role,
      onboardingCompleted: result.user.onboardingCompleted,
      registrationCompleted: result.user.registrationCompleted,
    },
    profile: {
      id: result.profile.id,
      displayName: result.profile.displayName || result.profile.fullName,
      fullName: result.profile.fullName,
      avatarUrl: result.profile.avatarUrl || result.profile.imageUrl,
      city: result.profile.city,
      district: result.profile.district,
      onboardingStep: result.profile.onboardingStep,
      registrationCompleted: result.profile.registrationCompleted,
    },
  };
};

export const loginWithEmailPassword = async (data: LoginDTO) => {
  const normalizedEmail = data.email.toLowerCase().trim();

  const user = await prisma.user.findFirst({
    where: { email: normalizedEmail },
    include: {
      profile: true,
      pets: {
        where: { isActive: true },
        take: 1,
      },
    },
  });

  if (!user || !user.passwordHash) {
    throw new AppError("Invalid email or password", 401);
  }

  if (!user.isActive) {
    throw new AppError("This account has been deactivated. Please contact support.", 403);
  }

  const isValidPassword = await bcrypt.compare(data.password, user.passwordHash);
  if (!isValidPassword) {
    throw new AppError("Invalid email or password", 401);
  }

  const token = generateAuthToken(user);
  const onboardingStep = user.profile?.onboardingStep ?? 1;
  const registrationCompleted =
    user.registrationCompleted || user.onboardingCompleted || false;

  return {
    token,
    user: {
      id: user.id,
      email: user.email,
      phoneNumber: user.phoneNumber,
      role: user.role,
      onboardingCompleted: user.onboardingCompleted,
      registrationCompleted,
    },
    profile: user.profile
      ? {
          id: user.profile.id,
          displayName: user.profile.displayName || user.profile.fullName,
          fullName: user.profile.fullName,
          avatarUrl: user.profile.avatarUrl || user.profile.imageUrl,
          city: user.profile.city,
          district: user.profile.district,
          onboardingStep,
          registrationCompleted,
        }
      : null,
    onboardingStep,
    registrationCompleted,
  };
};

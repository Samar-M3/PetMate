import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import prisma from "../../config/db.ts";
import env from "../../config/env.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { RegisterDTO, LoginDTO, SafeUser, AuthResponse, JwtPayload } from "./auth.types.ts";
import type { User } from "../../generated/prisma/client.ts";

const generateToken = (user: { id: string; email: string; role: any }): string => {
  const payload: JwtPayload = {
    userId: user.id,
    email: user.email,
    role: user.role,
  };
  return jwt.sign(payload, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN as any,
  });
};

const sanitizeUser = (user: User): SafeUser => {
  const { password, ...safeUser } = user;
  return safeUser as SafeUser;
};

export const registerUser = async (data: RegisterDTO): Promise<AuthResponse> => {
  const existingUser = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (existingUser) {
    throw new AppError("An account with this email already exists", 409);
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(data.password, salt);

  const newUser = await prisma.user.create({
    data: {
      email: data.email,
      password: hashedPassword,
      fullName: data.fullName,
      phoneNumber: data.phoneNumber,
      role: data.role || "PET_OWNER",
      status: "ACTIVE",
    },
  });

  const token = generateToken(newUser);
  return {
    user: sanitizeUser(newUser),
    token,
  };
};

export const loginUser = async (data: LoginDTO): Promise<AuthResponse> => {
  const user = await prisma.user.findUnique({
    where: { email: data.email },
  });

  if (!user) {
    throw new AppError("Invalid email or password", 401);
  }

  if (user.status === "SUSPENDED") {
    throw new AppError("Your account has been suspended. Please contact support.", 403);
  }

  const isPasswordMatch = await bcrypt.compare(data.password, user.password);
  if (!isPasswordMatch) {
    throw new AppError("Invalid email or password", 401);
  }

  const token = generateToken(user);
  return {
    user: sanitizeUser(user),
    token,
  };
};

export const getCurrentUserProfile = async (userId: string): Promise<SafeUser> => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new AppError("User not found", 404);
  }

  return sanitizeUser(user);
};

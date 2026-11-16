import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import prisma from "../../config/db.js";
import env from "../../config/env.js";
import { AppError } from "../../middleware/errorHandler.js";

const generateToken = (user) => {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
      role: user.role,
    },
    env.JWT_SECRET,
    {
      expiresIn: env.JWT_EXPIRES_IN,
    }
  );
};

const sanitizeUser = (user) => {
  const { password, ...safeUser } = user;
  return safeUser;
};

export const registerUser = async ({ email, password, fullName, phoneNumber, role }) => {
  const existingUser = await prisma.user.findUnique({
    where: { email },
  });

  if (existingUser) {
    throw new AppError("An account with this email already exists", 409);
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  const newUser = await prisma.user.create({
    data: {
      email,
      password: hashedPassword,
      fullName,
      phoneNumber,
      role: role || "PET_OWNER",
      status: "ACTIVE",
    },
  });

  const token = generateToken(newUser);
  return {
    user: sanitizeUser(newUser),
    token,
  };
};

export const loginUser = async ({ email, password }) => {
  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user) {
    throw new AppError("Invalid email or password", 401);
  }

  if (user.status === "SUSPENDED") {
    throw new AppError("Your account has been suspended. Please contact support.", 403);
  }

  const isPasswordMatch = await bcrypt.compare(password, user.password);
  if (!isPasswordMatch) {
    throw new AppError("Invalid email or password", 401);
  }

  const token = generateToken(user);
  return {
    user: sanitizeUser(user),
    token,
  };
};

export const getCurrentUserProfile = async (userId) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new AppError("User not found", 404);
  }

  return sanitizeUser(user);
};

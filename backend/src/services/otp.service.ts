import crypto from "node:crypto";
import prisma from "../config/db.ts";
import { AppError } from "../middleware/errorHandler.ts";

const OTP_EXPIRY_MINUTES = 5;
const RESET_TOKEN_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_OTPS_PER_HOUR = 5;

/**
 * Generate a cryptographically secure 6-digit OTP.
 */
export function generateOTP(): string {
  // crypto.randomInt is CSPRNG-backed; range [100000, 999999]
  return crypto.randomInt(100000, 1000000).toString();
}

/**
 * Hash an OTP using SHA-256 for safe storage.
 */
export function hashOTP(otp: string): string {
  return crypto.createHash("sha256").update(otp).digest("hex");
}

/**
 * Generate a cryptographically random reset token.
 */
export function generateResetToken(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Hash a reset token using SHA-256 for safe storage.
 */
export function hashResetToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/**
 * Create a new password-reset OTP for the given email.
 * Invalidates any previous unconsumed OTPs for the same email.
 * Enforces resend cooldown and hourly rate limit.
 * Returns the plaintext OTP for sending via email.
 */
export async function createPasswordResetOTP(
  email: string,
  ipAddress?: string
): Promise<string> {
  const normalizedEmail = email.toLowerCase().trim();

  // --- Resend cooldown check (60 s) ---
  const cooldownCutoff = new Date(Date.now() - RESEND_COOLDOWN_SECONDS * 1000);
  const recentOTP = await prisma.passwordResetOTP.findFirst({
    where: {
      email: normalizedEmail,
      createdAt: { gte: cooldownCutoff },
    },
    orderBy: { createdAt: "desc" },
  });

  if (recentOTP) {
    const secondsRemaining = Math.ceil(
      (recentOTP.createdAt.getTime() + RESEND_COOLDOWN_SECONDS * 1000 - Date.now()) / 1000
    );
    throw new AppError(
      `Please wait ${secondsRemaining} seconds before requesting a new code`,
      429
    );
  }

  // --- Hourly rate limit ---
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const hourlyCount = await prisma.passwordResetOTP.count({
    where: {
      email: normalizedEmail,
      createdAt: { gte: oneHourAgo },
    },
  });

  if (hourlyCount >= MAX_OTPS_PER_HOUR) {
    throw new AppError(
      "Too many password reset attempts. Please try again later.",
      429
    );
  }

  // --- Invalidate previous unconsumed OTPs for this email ---
  await prisma.passwordResetOTP.updateMany({
    where: { email: normalizedEmail, consumed: false },
    data: { consumed: true },
  });

  // --- Generate and store OTP ---
  const otp = generateOTP();
  const otpHashed = hashOTP(otp);
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  await prisma.passwordResetOTP.create({
    data: {
      email: normalizedEmail,
      otpHash: otpHashed,
      expiresAt,
      maxAttempts: MAX_ATTEMPTS,
      ipAddress: ipAddress || null,
    },
  });

  return otp;
}

export interface OTPVerificationResult {
  valid: boolean;
  otpRecordId?: string;
  errorMessage?: string;
}

/**
 * Verify an OTP for the given email.
 * Increments attempts on failure. Returns success/failure with an error message.
 */
export async function verifyOTP(
  email: string,
  otp: string
): Promise<OTPVerificationResult> {
  const normalizedEmail = email.toLowerCase().trim();
  const now = new Date();

  // Find the most recent non-consumed, non-expired OTP for this email
  const record = await prisma.passwordResetOTP.findFirst({
    where: {
      email: normalizedEmail,
      consumed: false,
      expiresAt: { gt: now },
    },
    orderBy: { createdAt: "desc" },
  });

  if (!record) {
    return {
      valid: false,
      errorMessage: "No valid verification code found. Please request a new one.",
    };
  }

  // Check attempts
  if (record.attempts >= record.maxAttempts) {
    // Mark as consumed so it can't be retried
    await prisma.passwordResetOTP.update({
      where: { id: record.id },
      data: { consumed: true },
    });
    return {
      valid: false,
      errorMessage: "Maximum verification attempts exceeded. Please request a new code.",
    };
  }

  // Compare hashes
  const incomingHash = hashOTP(otp);
  if (incomingHash !== record.otpHash) {
    // Increment attempts
    await prisma.passwordResetOTP.update({
      where: { id: record.id },
      data: { attempts: { increment: 1 } },
    });
    const remaining = record.maxAttempts - record.attempts - 1;
    return {
      valid: false,
      errorMessage:
        remaining > 0
          ? `Invalid code. ${remaining} attempt${remaining === 1 ? "" : "s"} remaining.`
          : "Maximum verification attempts exceeded. Please request a new code.",
    };
  }

  return { valid: true, otpRecordId: record.id };
}

export interface ResetTokenResult {
  resetToken: string;
}

/**
 * Issue a short-lived, single-use password reset token after OTP verification.
 * Marks the OTP record as consumed.
 */
export async function issueResetToken(otpRecordId: string): Promise<ResetTokenResult> {
  const plainToken = generateResetToken();
  const tokenHash = hashResetToken(plainToken);
  const expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRY_MINUTES * 60 * 1000);

  await prisma.passwordResetOTP.update({
    where: { id: otpRecordId },
    data: {
      consumed: true,
      resetToken: tokenHash,
      resetTokenExpiresAt: expiresAt,
      resetTokenConsumed: false,
    },
  });

  return { resetToken: plainToken };
}

export interface ConsumeTokenResult {
  valid: boolean;
  errorMessage?: string;
}

/**
 * Verify and consume a reset token.
 * Returns true only once — subsequent calls will fail.
 */
export async function consumeResetToken(
  email: string,
  token: string
): Promise<ConsumeTokenResult> {
  const normalizedEmail = email.toLowerCase().trim();
  const tokenHash = hashResetToken(token);
  const now = new Date();

  const record = await prisma.passwordResetOTP.findFirst({
    where: {
      email: normalizedEmail,
      resetToken: tokenHash,
      resetTokenConsumed: false,
      resetTokenExpiresAt: { gt: now },
    },
  });

  if (!record) {
    return {
      valid: false,
      errorMessage: "Invalid or expired reset token. Please start the password reset process again.",
    };
  }

  // Consume immediately
  await prisma.passwordResetOTP.update({
    where: { id: record.id },
    data: { resetTokenConsumed: true },
  });

  return { valid: true };
}

import type { Request, Response, NextFunction } from "express";
import bcrypt from "bcryptjs";
import prisma from "../../config/db.ts";
import { firebaseAuth } from "../../config/firebase.ts";
import { registerPetOwner, loginWithEmailPassword } from "./auth.service.ts";
import {
  validateRegister,
  validateLogin,
  validateForgotPassword,
  validateVerifyResetOTP,
  validateResetPassword,
} from "./auth.validation.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { createPasswordResetOTP, verifyOTP, issueResetToken, consumeResetToken } from "../../services/otp.service.ts";
import { emailService } from "../../services/email/email.service.ts";

export const register = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedData = validateRegister(req.body);
    const result = await registerPetOwner(validatedData);

    sendSuccess(res, {
      statusCode: 201,
      message: "Registration started successfully. Please complete your pet profile.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedData = validateLogin(req.body);
    const result = await loginWithEmailPassword(validatedData);

    sendSuccess(res, {
      statusCode: 200,
      message: "Login successful",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// ─── Forgot Password (Step 1: request OTP) ───────────────────────────────────

export const forgotPassword = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { email } = validateForgotPassword(req.body);
    const normalizedEmail = email.toLowerCase().trim();

    // Always return a generic success message to prevent email enumeration.
    const genericMessage =
      "If an account with that email exists, a verification code has been sent.";

    // Look up user
    const user = await prisma.user.findFirst({
      where: { email: normalizedEmail },
      include: { profile: true },
    });

    if (!user) {
      // Don't reveal whether the email exists
      sendSuccess(res, { message: genericMessage });
      return;
    }

    // Google-only accounts (no passwordHash) cannot reset a password
    if (!user.passwordHash) {
      // Still return generic success (no enumeration), but log it
      console.log(
        `[Auth] Forgot-password request for Google-only account (${normalizedEmail}). Skipping OTP.`
      );
      sendSuccess(res, { message: genericMessage });
      return;
    }

    // Deactivated accounts
    if (!user.isActive) {
      sendSuccess(res, { message: genericMessage });
      return;
    }

    // Generate OTP (enforces cooldown + rate limit — may throw 429)
    const ipAddress =
      (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() ||
      req.socket?.remoteAddress ||
      undefined;

    const otp = await createPasswordResetOTP(normalizedEmail, ipAddress);

    // Send OTP email (fire-and-forget for the response, but log errors)
    const displayName = user.profile?.displayName || user.profile?.fullName || undefined;
    emailService
      .sendOTPEmail({ to: normalizedEmail, displayName, otp, expiresInMinutes: 5 })
      .then((result) => {
        if (!result.delivered) {
          console.error(
            `[Auth] Failed to deliver OTP email to ${normalizedEmail}: ${result.errorCode} — ${result.errorMessage}`
          );
        }
      })
      .catch((err) => {
        console.error("[Auth] Unexpected error sending OTP email:", err);
      });

    sendSuccess(res, { message: genericMessage });
  } catch (error) {
    next(error);
  }
};

// ─── Verify Reset OTP (Step 2) ───────────────────────────────────────────────

export const verifyResetOTP = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { email, otp } = validateVerifyResetOTP(req.body);

    const result = await verifyOTP(email, otp);

    if (!result.valid) {
      throw new AppError(result.errorMessage || "Invalid verification code", 400);
    }

    // Issue a short-lived reset token
    const { resetToken } = await issueResetToken(result.otpRecordId!);

    sendSuccess(res, {
      message: "Verification successful",
      data: { resetToken },
    });
  } catch (error) {
    next(error);
  }
};

// ─── Reset Password (Step 3) ─────────────────────────────────────────────────

export const resetPassword = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { email, resetToken, newPassword } = validateResetPassword(req.body);
    const normalizedEmail = email.toLowerCase().trim();

    // 1. Consume the reset token (single-use)
    const tokenResult = await consumeResetToken(normalizedEmail, resetToken);
    if (!tokenResult.valid) {
      throw new AppError(
        tokenResult.errorMessage || "Invalid or expired reset token",
        400
      );
    }

    // 2. Find the user
    const user = await prisma.user.findFirst({
      where: { email: normalizedEmail },
      include: { profile: true },
    });

    if (!user) {
      throw new AppError("Account not found", 404);
    }

    if (!user.passwordHash) {
      throw new AppError(
        "This account uses Google Sign-In. Password reset is not available.",
        400
      );
    }

    // 3. Hash the new password for PostgreSQL
    const newPasswordHash = await bcrypt.hash(newPassword, 10);

    // 4. Update Firebase Auth password (if the user has a real Firebase UID)
    const hasRealFirebaseUid =
      user.firebaseUid && !user.firebaseUid.startsWith("uid_");

    if (hasRealFirebaseUid) {
      try {
        await firebaseAuth.updateUser(user.firebaseUid, {
          password: newPassword,
        });
        // Revoke all existing refresh tokens for security
        await firebaseAuth.revokeRefreshTokens(user.firebaseUid);
      } catch (firebaseErr: any) {
        console.error(
          `[Auth] Firebase password update failed for ${normalizedEmail}:`,
          firebaseErr?.message || firebaseErr
        );
        if (firebaseErr?.code === "auth/user-not-found") {
          // Firebase user doesn't exist — only update local hash
          console.warn(
            `[Auth] Firebase user not found for ${user.firebaseUid}. Updating local password only.`
          );
        } else if (firebaseErr?.code === "auth/invalid-password") {
          throw new AppError(
            "New password does not meet the security requirements",
            400
          );
        } else {
          throw new AppError(
            "Could not update the authentication password. Please try again.",
            502
          );
        }
      }
    }

    // 5. Update passwordHash in PostgreSQL
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: newPasswordHash },
    });

    // 6. Send password-changed notification email (fire-and-forget)
    const displayName =
      user.profile?.displayName || user.profile?.fullName || undefined;
    emailService
      .sendPasswordChangedEmail({
        to: normalizedEmail,
        displayName,
        changedAt: new Date(),
      })
      .catch((err) => {
        console.error("[Auth] Failed to send password-changed email:", err);
      });

    sendSuccess(res, {
      message: "Password has been reset successfully. Please log in with your new password.",
    });
  } catch (error) {
    next(error);
  }
};

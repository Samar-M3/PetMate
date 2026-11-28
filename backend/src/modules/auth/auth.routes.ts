import { Router } from "express";
import {
  register,
  login,
  forgotPassword,
  verifyResetOTP,
  resetPassword,
} from "./auth.controller.ts";

const router = Router();

// Rate limiting can be applied here or via global middleware
router.post("/register", register);
router.post("/login", login);

// Password reset flow (unauthenticated)
router.post("/forgot-password", forgotPassword);
router.post("/verify-reset-otp", verifyResetOTP);
router.post("/reset-password", resetPassword);

export default router;

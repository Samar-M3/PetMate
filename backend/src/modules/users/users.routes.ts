import { Router } from "express";
import {
  initializeUser,
  getMe,
  updateMe,
  getStatus,
} from "./users.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// Protected with Firebase authentication
router.use(authenticateFirebase);

// 1. Initialize user record
router.post("/initialize", initializeUser);

// 2. Check onboarding status
router.get("/onboarding-status", getStatus);

// 3. User details and profile updates (requires initialized user)
router.get("/me", requireInitializedUser, getMe);
router.put("/me", requireInitializedUser, updateMe);

export default router;

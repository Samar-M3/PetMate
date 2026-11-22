import { Router } from "express";
import {
  initializeUser,
  getMe,
  updateMe,
  uploadAvatar,
  getStatus,
  applyRole,
} from "./users.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

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

// 4. User avatar upload (multipart field name: "image")
router.post(
  "/me/avatar",
  requireInitializedUser,
  handleSingleImageUpload("image"),
  uploadAvatar
);

// 5. Submit role application (e.g. SELLER, VETERINARIAN)
router.post("/apply-role", requireInitializedUser, applyRole);

export default router;

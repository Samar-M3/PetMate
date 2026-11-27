import { Router } from "express";
import {
  initializeUser,
  changeInitialVeterinarianPassword,
  getMe,
  getPublicUser,
  updateMe,
  uploadAvatar,
  getStatus,
  applyRole,
  blockUserController,
} from "./users.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requirePasswordSetupComplete,
} from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

// Protected with Firebase authentication
router.use(authenticateFirebase);

// 1. Initialize user record
router.post("/initialize", requirePasswordSetupComplete, initializeUser);

// 2. Check onboarding status
router.get("/onboarding-status", getStatus);
router.post("/me/initial-password", requireInitializedUser, changeInitialVeterinarianPassword);

// 3. User details and profile updates (requires initialized user)
router.get("/me", requireInitializedUser, getMe);
router.get("/:id/public", requireInitializedUser, requirePasswordSetupComplete, getPublicUser);
router.put("/me", requireInitializedUser, requirePasswordSetupComplete, updateMe);

// 4. User avatar upload (multipart field name: "image")
router.post(
  "/me/avatar",
  requireInitializedUser,
  requirePasswordSetupComplete,
  handleSingleImageUpload("image"),
  uploadAvatar
);

// 5. Submit role application (e.g. SELLER, VETERINARIAN)
router.post("/apply-role", requireInitializedUser, requirePasswordSetupComplete, applyRole);

// 6. Block user
router.post("/:id/block", requireInitializedUser, requirePasswordSetupComplete, blockUserController);

export default router;

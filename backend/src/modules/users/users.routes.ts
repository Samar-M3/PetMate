import { Router } from "express";
import {
  initializeUser,
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
router.get("/:id/public", requireInitializedUser, getPublicUser);
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

// 6. Block user
router.post("/:id/block", requireInitializedUser, blockUserController);

export default router;

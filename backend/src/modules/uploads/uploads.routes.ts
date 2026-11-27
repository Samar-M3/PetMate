import { Router } from "express";
import { uploadImage, uploadPrivateImage } from "./uploads.controller.ts";
import {
  authenticateFirebase,
  authenticateOptionalFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

// Public/optional-auth upload endpoint for backwards compatibility (e.g. seller registration docs)
router.post(
  "/",
  authenticateOptionalFirebase,
  handleSingleImageUpload("image"),
  uploadImage
);

// Authenticated image upload (jpg/png/webp, max 5 MB)
router.post(
  "/image",
  authenticateFirebase,
  requireInitializedUser,
  handleSingleImageUpload("image"),
  uploadImage
);

// Private/authenticated Cloudinary asset upload (for vet records, PET_OWNER only)
router.post(
  "/private-image",
  authenticateFirebase,
  requireInitializedUser,
  requireRole(Role.PET_OWNER, Role.ADMIN),
  handleSingleImageUpload("image"),
  uploadPrivateImage
);

export default router;

import { Router } from "express";
import {
  register,
  getStatus,
  resubmit,
  requestPasswordReset,
  getDashboard,
} from "./sellers.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";
import { requireApprovedSeller } from "./sellers.middleware.ts";
import { uploadImage } from "../uploads/uploads.controller.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

// Public endpoints
router.post("/register", register);
router.post("/forgot-password", requestPasswordReset);
router.post("/upload-document", handleSingleImageUpload("image"), uploadImage);

// Authenticated seller endpoints
router.get("/status", authenticateFirebase, requireInitializedUser, getStatus);
router.get("/me", authenticateFirebase, requireInitializedUser, getStatus);
router.put("/resubmit", authenticateFirebase, requireInitializedUser, resubmit);
router.patch("/resubmit", authenticateFirebase, requireInitializedUser, resubmit);

// Protected dashboard (approved sellers only)
router.get(
  "/dashboard",
  authenticateFirebase,
  requireInitializedUser,
  requireApprovedSeller,
  getDashboard
);

export default router;

import { Router } from "express";
import { uploadImage } from "./uploads.controller.ts";
import { authenticateFirebase } from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

// Protected with Firebase authentication
router.use(authenticateFirebase);

// Upload endpoint supporting multipart "image" file
router.post("/", handleSingleImageUpload("image"), uploadImage);

export default router;

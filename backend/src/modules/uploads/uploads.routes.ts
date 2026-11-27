import { Router } from "express";
import { uploadImage } from "./uploads.controller.ts";
import { authenticateOptionalFirebase } from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

// Support authenticated uploads and public registration/verification uploads
router.use(authenticateOptionalFirebase);

// Upload endpoint supporting multipart "image" file
router.post("/", handleSingleImageUpload("image"), uploadImage);

export default router;

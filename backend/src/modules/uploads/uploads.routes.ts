import { Router } from "express";
import { getSignature, uploadImage } from "./uploads.controller.ts";
import { authenticateFirebase } from "../../middleware/auth.middleware.ts";

const router = Router();

// Protected with Firebase authentication
router.use(authenticateFirebase);

router.post("/signature", getSignature);
router.post("/", uploadImage);

export default router;

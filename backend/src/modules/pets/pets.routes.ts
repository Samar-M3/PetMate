import { Router } from "express";
import {
  createPet,
  getPets,
  getSinglePet,
  updatePet,
  activatePet,
  deletePet,
  uploadPetImage,
  deletePetImageHandler,
} from "./pets.controller.ts";
import { getSummary } from "../slots/slots.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";
import { handleSingleImageUpload } from "../../middleware/upload.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);
router.use(requireRole(Role.PET_OWNER, Role.ADMIN));

router.post("/", createPet);
router.get("/", getPets);
router.get("/:id", getSinglePet);
router.put("/:id", updatePet);
router.delete("/:id", deletePet);

// Pet activation summary & activation endpoint
router.get("/activation/summary", getSummary);
router.post("/:id/activation", activatePet);

// Pet image endpoints (multipart field name: "image")
router.post("/:id/image", handleSingleImageUpload("image"), uploadPetImage);
router.delete("/:id/image", deletePetImageHandler);

export default router;

import { Router } from "express";
import {
  createPet,
  getPets,
  getSinglePet,
  updatePet,
  deletePet,
} from "./pets.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);

router.post("/", createPet);
router.get("/", getPets);
router.get("/:id", getSinglePet);
router.put("/:id", updatePet);
router.delete("/:id", deletePet);

export default router;

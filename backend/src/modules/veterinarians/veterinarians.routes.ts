import { Router } from "express";
import {
  getVeterinarians,
  getMyVetProfile,
  addVeterinarian,
  updateVeterinarian,
  updateVetSlots,
  removeVeterinarian,
} from "./veterinarians.controller.ts";
import {
  authenticateAdmin,
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// Public / User read
router.get("/", getVeterinarians);
router.get("/me", authenticateFirebase, requireInitializedUser, getMyVetProfile);
router.patch("/:id/slots", authenticateFirebase, requireInitializedUser, updateVetSlots);

// Admin-only management
router.post(
  "/",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  addVeterinarian
);

router.patch(
  "/:id",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  updateVeterinarian
);

router.delete(
  "/:id",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  removeVeterinarian
);

export default router;

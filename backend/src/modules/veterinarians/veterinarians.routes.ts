import { Router } from "express";
import {
  getVeterinarians,
  getMyVetProfile,
  addVeterinarian,
  updateVeterinarian,
  updateVetSlots,
  removeVeterinarian,
  vetLogin,
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

// Vet login (public)
router.post("/login", vetLogin);

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

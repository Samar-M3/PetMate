import { Router } from "express";
import {
  getVeterinarians,
  addVeterinarian,
  removeVeterinarian,
} from "./veterinarians.controller.ts";
import {
  authenticateAdmin,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// Public / User read
router.get("/", getVeterinarians);

// Admin-only management
router.post(
  "/",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  addVeterinarian
);

router.delete(
  "/:id",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  removeVeterinarian
);

export default router;

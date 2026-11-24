import { Router } from "express";
import {
  getAppointments,
  bookAppointment,
  updateStatus,
} from "./appointments.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requirePasswordSetupComplete,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);
router.use(requirePasswordSetupComplete);

router.get("/", getAppointments);
router.post("/", bookAppointment);
router.patch("/:id/status", requireRole(Role.VETERINARIAN, Role.ADMIN), updateStatus);

export default router;

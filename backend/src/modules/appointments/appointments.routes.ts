import { Router } from "express";
import {
  getAppointments,
  bookAppointment,
  updateStatus,
} from "./appointments.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);

router.get("/", getAppointments);
router.post("/", bookAppointment);
router.patch("/:id/status", updateStatus);

export default router;

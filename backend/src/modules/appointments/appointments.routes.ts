import { Router } from "express";
import {
  getAppointments,
  bookAppointment,
  updateStatus,
  getBookedSlotsHandler,
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
router.get("/booked-slots", getBookedSlotsHandler);

export default router;

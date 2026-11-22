import { Router } from "express";
import { getEvents, addEvent, removeEvent } from "./events.controller.ts";
import {
  authenticateAdmin,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// Public / User read
router.get("/", getEvents);

// Admin-only management
router.post(
  "/",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  addEvent
);

router.delete(
  "/:id",
  authenticateAdmin,
  requireInitializedUser,
  requireRole(Role.ADMIN),
  removeEvent
);

export default router;

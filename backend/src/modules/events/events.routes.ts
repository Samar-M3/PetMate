import { Router } from "express";
import { getEvents, addEvent, removeEvent, bookmarkEvent, rsvpEvent } from "./events.controller.ts";
import {
  authenticateAdmin,
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// Public / User read
router.get("/", getEvents);

// User actions
router.post("/:id/bookmark", authenticateFirebase, requireInitializedUser, bookmarkEvent);
router.post("/:id/rsvp", authenticateFirebase, requireInitializedUser, rsvpEvent);

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

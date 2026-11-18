import { Router } from "express";
import {
  getDiscover,
  postSwipe,
  getIncoming,
  acceptRequest,
  rejectRequest,
} from "./matching.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);
router.use(requireRole(Role.PET_OWNER, Role.ADMIN));

router.get("/discover", getDiscover);
router.post("/swipes", postSwipe);
router.get("/requests/incoming", getIncoming);
router.post("/requests/:id/accept", acceptRequest);
router.post("/requests/:id/reject", rejectRequest);

export default router;

import { Router } from "express";
import {
  getDeck,
  postSwipe,
  postUndoSwipe,
  getIncoming,
  acceptRequest,
  rejectRequest,
  getMatches,
  getMatchChatHandler,
  unmatchHandler,
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

// Deck endpoints (support both /deck and legacy /discover)
router.get("/deck", getDeck);
router.get("/discover", getDeck);

// Swipe endpoints
router.post("/swipes", postSwipe);
router.post("/swipes/undo", postUndoSwipe);

// Request endpoints
router.get("/requests/incoming", getIncoming);
router.post("/requests/:id/accept", acceptRequest);
router.post("/requests/:id/reject", rejectRequest);
router.post("/requests/:id/decline", rejectRequest);

// Matches / Conversations endpoints
router.get("/matches", getMatches);
router.get("/matches/:id/chat", getMatchChatHandler);
router.post("/matches/:id/unmatch", unmatchHandler);

export default router;

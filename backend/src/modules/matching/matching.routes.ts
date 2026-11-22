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

const matchingAuth = [
  authenticateFirebase,
  requireInitializedUser,
  requireRole(Role.PET_OWNER, Role.ADMIN),
];

// Deck endpoints (support both /deck and legacy /discover)
router.get("/deck", matchingAuth, getDeck);
router.get("/discover", matchingAuth, getDeck);

// Swipe endpoints
router.post("/swipes", matchingAuth, postSwipe);
router.post("/swipes/undo", matchingAuth, postUndoSwipe);

// Request endpoints
router.get("/requests/incoming", matchingAuth, getIncoming);
router.post("/requests/:id/accept", matchingAuth, acceptRequest);
router.post("/requests/:id/reject", matchingAuth, rejectRequest);
router.post("/requests/:id/decline", matchingAuth, rejectRequest);

// Matches / Conversations endpoints
router.get("/matches", matchingAuth, getMatches);
router.get("/matches/:id/chat", matchingAuth, getMatchChatHandler);
router.post("/matches/:id/unmatch", matchingAuth, unmatchHandler);

export default router;

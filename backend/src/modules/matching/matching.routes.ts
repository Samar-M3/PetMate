import { Router } from "express";
import {
  getDeck,
  postSwipe,
  postUndoSwipe,
  postResetPasses,
  getIncoming,
  getOutgoing,
  acceptRequest,
  rejectRequest,
  patchRequestMessage,
  cancelRequest,
  getAllConnectionsHandler,
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
router.post("/swipes/reset-passes", matchingAuth, postResetPasses);

// Request endpoints
router.get("/requests/incoming", matchingAuth, getIncoming);
router.get("/requests/outgoing", matchingAuth, getOutgoing);
router.post("/requests/:id/accept", matchingAuth, acceptRequest);
router.post("/requests/:id/reject", matchingAuth, rejectRequest);
router.post("/requests/:id/decline", matchingAuth, rejectRequest);
router.post("/requests/:id/cancel", matchingAuth, cancelRequest);
router.patch("/requests/:id/message", matchingAuth, patchRequestMessage);

// Unified connections endpoint for "All" filter
router.get("/connections/all", matchingAuth, getAllConnectionsHandler);

// Matches / Conversations endpoints
router.get("/matches", matchingAuth, getMatches);
router.get("/matches/:id/chat", matchingAuth, getMatchChatHandler);
router.post("/matches/:id/unmatch", matchingAuth, unmatchHandler);

export default router;

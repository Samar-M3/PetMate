import { Router } from "express";
import { reportChatController } from "./chat.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);

// POST /chats/:conversationId/report
router.post("/:conversationId/report", reportChatController);

export default router;

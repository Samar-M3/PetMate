import { Router } from "express";
import {
  reportChatController,
  signatureController,
  mediaMessageController,
  deleteForEveryoneController,
  batchDeleteController,
  mediaUrlsController,
  notifyChatMessageController,
} from "./chat.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
} from "../../middleware/auth.middleware.ts";

const router = Router();
router.use(authenticateFirebase);
router.use(requireInitializedUser);

// Existing
router.post("/:conversationId/report", reportChatController);

// Media upload signature
router.post("/:conversationId/media/signature", signatureController);

// Create media message
router.post("/:conversationId/messages/media", mediaMessageController);

// Delete message for everyone
router.delete("/:conversationId/messages/:messageId", deleteForEveryoneController);

// Batch delete messages for everyone
router.post("/:conversationId/messages/delete", batchDeleteController);

// Get signed delivery URLs
router.post("/:conversationId/media/urls", mediaUrlsController);

// Notify chat message push trigger
router.post("/:conversationId/notify", notifyChatMessageController);

export default router;

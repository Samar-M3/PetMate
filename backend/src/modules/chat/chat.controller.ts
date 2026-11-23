import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import prisma from "../../config/db.ts";
import { getMessageSnapshot, createMediaMessage, deleteMessageForEveryone } from "../../services/firestore.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import chatConfig from "../../config/chat.config.ts";
import {
  verifyParticipant,
  verifyActiveConversation,
  generateUploadSignature,
  validateMediaItems,
  generateDeliveryUrls,
  runMediaRetention,
} from "./chat.service.ts";

// ---------------------------------------------------------------------------
// Report (existing – kept verbatim)
// ---------------------------------------------------------------------------

export const reportChatController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("User not authenticated", 401));
    }

    const { conversationId } = req.params;
    if (!conversationId || typeof conversationId !== "string") {
      return next(new AppError("Conversation ID is required", 400));
    }

    const { messageId, reason } = req.body ?? {};
    if (!reason || typeof reason !== "string" || !reason.trim()) {
      return next(new AppError("Reason is required", 400));
    }

    // Verify caller owns one of the two pets in the match
    const match = await prisma.match.findUnique({
      where: { id: conversationId },
      include: {
        petA: { select: { userId: true } },
        petB: { select: { userId: true } },
      },
    });

    if (!match) {
      return next(new AppError("Conversation not found", 404));
    }

    const isParticipant =
      match.petA.userId === req.user.id || match.petB.userId === req.user.id;
    if (!isParticipant) {
      return next(new AppError("Conversation not found", 404));
    }

    // Fetch snapshot securely from Firestore Admin SDK without trusting client text
    const snapshot = await getMessageSnapshot(
      conversationId,
      messageId ? String(messageId).trim() : undefined
    );

    const report = await prisma.chatReport.create({
      data: {
        reporterId: req.user.id,
        conversationId,
        messageId: messageId ? String(messageId).trim() : null,
        reason: reason.trim(),
        snapshot: snapshot ?? undefined,
      },
    });

    sendSuccess(res, {
      statusCode: 201,
      message: "Report submitted successfully",
      data: {
        reportId: report.id,
        createdAt: report.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ---------------------------------------------------------------------------
// POST /:conversationId/media/signature
// ---------------------------------------------------------------------------

export const signatureController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user || !req.firebaseUid)
      return next(new AppError("User not authenticated", 401));

    const conversationId = req.params.conversationId;
    if (!conversationId || typeof conversationId !== "string")
      return next(new AppError("Conversation ID is required", 400));

    const { kind, mimeType, sizeBytes } = req.body ?? {};
    if (!kind || !mimeType || !sizeBytes)
      return next(
        new AppError("kind, mimeType and sizeBytes are required", 400),
      );

    const { callerFirebaseUid } = await verifyParticipant(
      conversationId,
      req.user.id,
    );
    await verifyActiveConversation(conversationId);

    const params = await generateUploadSignature(
      conversationId,
      kind,
      mimeType,
      Number(sizeBytes),
      callerFirebaseUid,
    );
    sendSuccess(res, { data: params });
  } catch (error) {
    next(error);
  }
};

// ---------------------------------------------------------------------------
// POST /:conversationId/messages/media
// ---------------------------------------------------------------------------

export const mediaMessageController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user || !req.firebaseUid)
      return next(new AppError("User not authenticated", 401));

    const conversationId = req.params.conversationId;
    if (!conversationId || typeof conversationId !== "string")
      return next(new AppError("Conversation ID is required", 400));

    const { clientMessageId, items, caption, replyTo } = req.body ?? {};
    if (!clientMessageId || typeof clientMessageId !== "string")
      return next(new AppError("clientMessageId is required", 400));
    if (!Array.isArray(items) || items.length === 0)
      return next(new AppError("items array is required", 400));
    if (items.length > chatConfig.CHAT_MAX_MEDIA_PER_MESSAGE)
      return next(
        new AppError(
          `Maximum ${chatConfig.CHAT_MAX_MEDIA_PER_MESSAGE} items per message`,
          400,
        ),
      );
    if (caption && typeof caption === "string" && caption.length > 1000)
      return next(
        new AppError("Caption cannot exceed 1000 characters", 400),
      );

    // Validate replyTo structure if present
    if (replyTo) {
      if (
        typeof replyTo !== "object" ||
        !replyTo.messageId ||
        !replyTo.senderUid ||
        !replyTo.type
      ) {
        return next(new AppError("Invalid replyTo format", 400));
      }
      if (
        replyTo.preview &&
        typeof replyTo.preview === "string" &&
        replyTo.preview.length > 100
      ) {
        return next(
          new AppError("Reply preview cannot exceed 100 characters", 400),
        );
      }
    }

    const { callerFirebaseUid, otherFirebaseUid } = await verifyParticipant(
      conversationId,
      req.user.id,
    );
    await verifyActiveConversation(conversationId);

    // Validate each item exists in Cloudinary
    const validatedItems = await validateMediaItems(
      conversationId,
      items,
      callerFirebaseUid,
    );

    const msgData = await createMediaMessage(
      conversationId,
      clientMessageId,
      callerFirebaseUid,
      otherFirebaseUid,
      validatedItems,
      caption?.trim() || undefined,
      replyTo
        ? {
            messageId: replyTo.messageId,
            senderUid: replyTo.senderUid,
            type: replyTo.type,
            preview: (replyTo.preview || "").slice(0, 100),
          }
        : undefined,
    );

    sendSuccess(res, {
      statusCode: 201,
      message: "Media message created",
      data: { messageId: clientMessageId },
    });
  } catch (error) {
    next(error);
  }
};

// ---------------------------------------------------------------------------
// DELETE /:conversationId/messages/:messageId?scope=everyone
// ---------------------------------------------------------------------------

export const deleteForEveryoneController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user || !req.firebaseUid)
      return next(new AppError("User not authenticated", 401));

    const conversationId = req.params.conversationId;
    const messageId = req.params.messageId;
    if (
      !conversationId ||
      typeof conversationId !== "string" ||
      !messageId ||
      typeof messageId !== "string"
    )
      return next(
        new AppError("Conversation and message IDs required", 400),
      );

    const scope = req.query.scope;
    if (scope !== "everyone")
      return next(
        new AppError("Only scope=everyone is supported via backend", 400),
      );

    const { callerFirebaseUid } = await verifyParticipant(
      conversationId,
      req.user.id,
    );
    await verifyActiveConversation(conversationId);

    const result = await deleteMessageForEveryone(
      conversationId,
      messageId,
      callerFirebaseUid,
      chatConfig.CHAT_DELETE_FOR_EVERYONE_WINDOW_MINUTES,
    );
    sendSuccess(res, { message: result.message });
  } catch (error) {
    next(error);
  }
};

// ---------------------------------------------------------------------------
// POST /:conversationId/media/urls
// ---------------------------------------------------------------------------

export const mediaUrlsController = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user || !req.firebaseUid)
      return next(new AppError("User not authenticated", 401));

    const conversationId = req.params.conversationId;
    if (!conversationId || typeof conversationId !== "string")
      return next(new AppError("Conversation ID is required", 400));

    const { publicIds, items } = req.body ?? {};
    const targets: Array<{
      publicId: string;
      kind?: "image" | "video";
      thumbnail?: boolean;
    }> = [];

    if (Array.isArray(items) && items.length > 0) {
      for (const item of items) {
        if (typeof item === "string") {
          targets.push({ publicId: item });
        } else if (item && typeof item.publicId === "string") {
          targets.push({
            publicId: item.publicId,
            kind: item.kind,
            thumbnail: item.thumbnail,
          });
        }
      }
    } else if (Array.isArray(publicIds) && publicIds.length > 0) {
      for (const id of publicIds) {
        if (typeof id === "string") {
          targets.push({ publicId: id });
        }
      }
    } else {
      return next(new AppError("publicIds array required", 400));
    }

    if (targets.length > 50)
      return next(new AppError("Maximum 50 publicIds per request", 400));

    await verifyParticipant(conversationId, req.user.id);
    const urls = await generateDeliveryUrls(conversationId, targets);
    sendSuccess(res, { data: urls });
  } catch (error) {
    next(error);
  }
};

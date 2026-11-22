import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import prisma from "../../config/db.ts";
import { getMessageSnapshot } from "../../services/firestore.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

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

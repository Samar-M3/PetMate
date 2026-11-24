import cloudinary from "../../config/cloudinary.ts";
import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import chatConfig from "../../config/chat.config.ts";
import { FieldValue } from "firebase-admin/firestore";
import { firestore, rtdb } from "../../config/firebase.ts";
import { NotificationService } from "../../services/notification.service.ts";
import {
  getConversationDoc,
  createMediaMessage,
  deleteMessageForEveryone,
  cleanupExpiredChatMedia,
  deleteCloudinaryAssets,
} from "../../services/firestore.service.ts";
import type {
  MediaItemInput,
  ReplyToInput,
} from "../../services/firestore.service.ts";
import crypto from "node:crypto";

// ---------------------------------------------------------------------------
// In-memory rate limiter
// ---------------------------------------------------------------------------

const uploadRateLimits = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(uid: string): void {
  const now = Date.now();
  const entry = uploadRateLimits.get(uid);
  if (!entry || now > entry.resetAt) {
    uploadRateLimits.set(uid, { count: 1, resetAt: now + 3600_000 });
    return;
  }
  if (entry.count >= chatConfig.CHAT_MEDIA_UPLOADS_PER_HOUR) {
    throw new AppError(
      "Media upload rate limit exceeded. Please try again later.",
      429,
    );
  }
  entry.count++;
}

// ---------------------------------------------------------------------------
// verifyParticipant
// ---------------------------------------------------------------------------

export async function verifyParticipant(
  conversationId: string,
  userId: string,
) {
  const match = await prisma.match.findUnique({
    where: { id: conversationId },
    include: {
      petA: {
        select: {
          userId: true,
          user: { select: { firebaseUid: true } },
        },
      },
      petB: {
        select: {
          userId: true,
          user: { select: { firebaseUid: true } },
        },
      },
    },
  });

  if (!match) {
    throw new AppError("Conversation not found", 404);
  }

  const isPetAOwner = match.petA.userId === userId;
  const isPetBOwner = match.petB.userId === userId;

  if (!isPetAOwner && !isPetBOwner) {
    throw new AppError("You are not a participant in this conversation", 403);
  }

  const callerFirebaseUid = isPetAOwner
    ? match.petA.user.firebaseUid
    : match.petB.user.firebaseUid;

  const otherFirebaseUid = isPetAOwner
    ? match.petB.user.firebaseUid
    : match.petA.user.firebaseUid;

  const otherUserId = isPetAOwner ? match.petB.userId : match.petA.userId;

  return { match, callerFirebaseUid, otherFirebaseUid, otherUserId };
}

// ---------------------------------------------------------------------------
// verifyActiveConversation
// ---------------------------------------------------------------------------

export async function verifyActiveConversation(conversationId: string) {
  const doc = await getConversationDoc(conversationId);

  if (!doc || doc.status !== "ACTIVE") {
    throw new AppError("Conversation is not active", 400);
  }

  return doc;
}

// ---------------------------------------------------------------------------
// generateUploadSignature
// ---------------------------------------------------------------------------

export async function generateUploadSignature(
  conversationId: string,
  kind: string,
  mimeType: string,
  sizeBytes: number,
  callerFirebaseUid: string,
) {
  // Validate kind
  if (kind !== "image" && kind !== "video") {
    throw new AppError("kind must be 'image' or 'video'", 400);
  }

  // Validate mime type
  const allowedMimes =
    kind === "image"
      ? chatConfig.ALLOWED_IMAGE_MIME_TYPES
      : chatConfig.ALLOWED_VIDEO_MIME_TYPES;

  if (!allowedMimes.includes(mimeType)) {
    throw new AppError(`Unsupported ${kind} mime type: ${mimeType}`, 400);
  }

  // Validate size
  const maxBytes =
    kind === "image"
      ? chatConfig.CHAT_MAX_IMAGE_MB * 1024 * 1024
      : chatConfig.CHAT_MAX_VIDEO_MB * 1024 * 1024;

  if (sizeBytes > maxBytes) {
    const maxMb =
      kind === "image"
        ? chatConfig.CHAT_MAX_IMAGE_MB
        : chatConfig.CHAT_MAX_VIDEO_MB;
    throw new AppError(`File exceeds maximum size of ${maxMb} MB`, 400);
  }

  // Rate limit
  checkRateLimit(callerFirebaseUid);

  // Build signature params
  const folder = `${chatConfig.CLOUDINARY_CHAT_FOLDER}/${conversationId}`;
  const publicId = crypto.randomUUID();
  const timestamp = Math.floor(Date.now() / 1000);
  const resource_type = kind === "video" ? "video" : "image";

  // Build eager transformations
  const eager =
    kind === "image"
      ? "c_limit,w_400,h_400,f_auto,q_auto"
      : "f_mp4,vc_h264/c_limit,w_720|f_jpg,w_400,h_400,c_fill,so_0";

  const allowedFormats =
    kind === "image"
      ? chatConfig.ALLOWED_IMAGE_FORMATS
      : chatConfig.ALLOWED_VIDEO_FORMATS;

  const params: Record<string, any> = {
    timestamp,
    folder,
    public_id: publicId,
    type: "authenticated",
    eager,
    allowed_formats: allowedFormats.join(","),
  };

  const signature = cloudinary.utils.api_sign_request(
    params,
    cloudinary.config().api_secret!,
  );

  return {
    apiKey: cloudinary.config().api_key,
    cloudName: cloudinary.config().cloud_name,
    timestamp,
    signature,
    folder,
    publicId,
    resourceType: resource_type,
    type: "authenticated" as const,
    eager,
    allowedFormats,
  };
}

// ---------------------------------------------------------------------------
// validateMediaItems
// ---------------------------------------------------------------------------

export async function validateMediaItems(
  conversationId: string,
  items: Array<{
    kind: "image" | "video";
    publicId: string;
    format: string;
    width: number;
    height: number;
    durationSeconds?: number;
    thumbnailPublicId?: string;
  }>,
  callerFirebaseUid: string,
): Promise<MediaItemInput[]> {
  const folderPrefix = `${chatConfig.CLOUDINARY_CHAT_FOLDER}/${conversationId}/`;
  const allPublicIds: Array<{ publicId: string; kind: string }> = [];

  try {
    const validated: MediaItemInput[] = [];

    for (const item of items) {
      const publicId = item.publicId.startsWith(folderPrefix)
        ? item.publicId
        : `${folderPrefix}${item.publicId}`;

      allPublicIds.push({ publicId, kind: item.kind });

      const resourceType = item.kind === "video" ? "video" : "image";

      // Verify the resource exists in Cloudinary
      const resource = await cloudinary.api.resource(publicId, {
        type: "authenticated",
        resource_type: resourceType,
      });

      // Validate size
      const maxBytes =
        item.kind === "image"
          ? chatConfig.CHAT_MAX_IMAGE_MB * 1024 * 1024
          : chatConfig.CHAT_MAX_VIDEO_MB * 1024 * 1024;

      if (resource.bytes > maxBytes) {
        throw new AppError(
          `${item.kind} exceeds maximum allowed size`,
          400,
        );
      }

      // Validate video duration
      if (
        item.kind === "video" &&
        resource.duration != null &&
        resource.duration > chatConfig.CHAT_MAX_VIDEO_SECONDS
      ) {
        throw new AppError(
          `Video exceeds maximum duration of ${chatConfig.CHAT_MAX_VIDEO_SECONDS} seconds`,
          400,
        );
      }

      const mediaItem: MediaItemInput = {
        kind: item.kind,
        publicId,
        format: item.format,
        bytes: resource.bytes,
        width: item.width,
        height: item.height,
      };

      if (item.durationSeconds != null) {
        mediaItem.durationSeconds = item.durationSeconds;
      }

      if (item.thumbnailPublicId) {
        mediaItem.thumbnailPublicId = item.thumbnailPublicId.startsWith(folderPrefix)
          ? item.thumbnailPublicId
          : `${folderPrefix}${item.thumbnailPublicId}`;
      }

      validated.push(mediaItem);
    }

    return validated;
  } catch (error) {
    // On any validation failure, clean up all uploaded assets
    if (allPublicIds.length > 0) {
      const imgIds = allPublicIds.filter((i) => i.kind === "image").map((i) => i.publicId);
      const vidIds = allPublicIds.filter((i) => i.kind === "video").map((i) => i.publicId);
      try {
        if (imgIds.length > 0) await deleteCloudinaryAssets(imgIds, "image");
        if (vidIds.length > 0) await deleteCloudinaryAssets(vidIds, "video");
      } catch {
        // Best-effort cleanup; swallow errors
      }
    }
    throw error;
  }
}

// ---------------------------------------------------------------------------
// generateDeliveryUrls
// ---------------------------------------------------------------------------

export async function generateDeliveryUrls(
  conversationId: string,
  targets: Array<
    { publicId: string; kind?: "image" | "video"; thumbnail?: boolean } | string
  >,
): Promise<Record<string, string>> {
  const folderPrefix = `${chatConfig.CLOUDINARY_CHAT_FOLDER}/${conversationId}/`;
  const urls: Record<string, string> = {};

  for (const item of targets) {
    const publicId = typeof item === "string" ? item : item.publicId;
    const kind = typeof item === "object" ? item.kind : undefined;
    const isThumb = typeof item === "object" ? item.thumbnail : false;

    if (!publicId.startsWith(folderPrefix)) {
      throw new AppError(
        "Invalid publicId: does not belong to this conversation",
        400,
      );
    }

    // Cloudinary delivery URLs must use resource_type "image" or "video" (never "auto").
    // Video streaming requires resource_type "video".
    // Images and video poster thumbnails use format jpg/auto.
    const isVideo = kind === "video";
    const resourceType = isVideo ? "video" : "image";

    const options: Record<string, any> = {
      type: "authenticated",
      sign_url: true,
      secure: true,
      resource_type: resourceType,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
    };

    if (isVideo && isThumb) {
      options.format = "jpg";
      options.transformation = [
        { width: 400, height: 400, crop: "fill", start_offset: 0 },
      ];
    }

    const signedUrl = cloudinary.url(publicId, options);
    urls[publicId] = signedUrl;
  }

  return urls;
}

// ---------------------------------------------------------------------------
// runMediaRetention
// ---------------------------------------------------------------------------

export async function runMediaRetention(): Promise<number> {
  const count = await cleanupExpiredChatMedia(
    chatConfig.CHAT_MEDIA_RETENTION_DAYS,
  );
  return count;
}

// ---------------------------------------------------------------------------
// notifyChatMessage
// ---------------------------------------------------------------------------

export async function notifyChatMessage(
  conversationId: string,
  messageId: string,
  callerUserId: string,
  callerFirebaseUid: string
): Promise<{ notified: boolean; reason?: string }> {
  // 1. Verify caller is a participant in PostgreSQL match
  const { match, otherUserId, otherFirebaseUid } = await verifyParticipant(
    conversationId,
    callerUserId
  );

  if (match.status !== "ACTIVE") {
    return { notified: false, reason: "Conversation is ended or inactive" };
  }

  // 2. Verify conversation in Firestore is ACTIVE
  const convDoc = await firestore.collection("conversations").doc(conversationId).get();
  if (!convDoc.exists) {
    throw new AppError("Conversation document not found", 404);
  }
  const convData = convDoc.data()!;
  if (convData.status !== "ACTIVE") {
    return { notified: false, reason: "Conversation is not active in Firestore" };
  }

  // 3. Atomically check & set notifiedAt on the message document for idempotency
  const messageRef = firestore
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .doc(messageId);

  const txResult = await firestore.runTransaction(async (t) => {
    const doc = await t.get(messageRef);
    if (!doc.exists) {
      return { exists: false };
    }
    const data = doc.data()!;
    if (data.notifiedAt) {
      return { exists: true, alreadyNotified: true, data };
    }
    t.update(messageRef, { notifiedAt: FieldValue.serverTimestamp() });
    return { exists: true, alreadyNotified: false, data };
  });

  if (!txResult.exists) {
    throw new AppError("Message not found", 404);
  }

  if (txResult.alreadyNotified) {
    return { notified: false, reason: "Already notified" };
  }

  const msgData = txResult.data!;

  // 4. Verify caller is the sender of this message
  if (msgData.senderUid !== callerFirebaseUid) {
    throw new AppError("Caller is not the sender of this message", 403);
  }

  // 5. Never send for deleted messages
  if (
    msgData.deletedForEveryone === true ||
    (Array.isArray(msgData.deletedForUsers) && msgData.deletedForUsers.includes(otherFirebaseUid))
  ) {
    return { notified: false, reason: "Message is deleted" };
  }

  // 6. Check recipient active status & user blocks in PostgreSQL
  const recipient = await prisma.user.findUnique({
    where: { id: otherUserId },
    include: { profile: true },
  });

  if (!recipient || !recipient.isActive) {
    return { notified: false, reason: "Recipient account is inactive or not found" };
  }

  const isBlocked = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: otherUserId, blockedId: callerUserId },
        { blockerId: callerUserId, blockedId: otherUserId },
      ],
    },
  });

  if (isBlocked) {
    return { notified: false, reason: "User is blocked" };
  }

  // 7. Presence check: if recipient has active connections in RTDB, skip sending push
  try {
    const connectionsSnap = await rtdb.ref(`status/${otherFirebaseUid}/connections`).get();
    if (connectionsSnap.exists()) {
      const val = connectionsSnap.val();
      if (val && typeof val === "object" && Object.keys(val).length > 0) {
        return { notified: false, reason: "Recipient is currently online" };
      }
    }
  } catch (err) {
    // If RTDB check fails, fail open and proceed with push
  }

  // 8. Format title and body
  const callerUser = await prisma.user.findUnique({
    where: { id: callerUserId },
    include: { profile: true },
  });
  const senderName = callerUser?.profile?.fullName || callerUser?.email?.split("@")[0] || "Pet parent";

  let bodyText = "New message";
  if (msgData.type === "media" || (Array.isArray(msgData.media) && msgData.media.length > 0)) {
    const mediaList = msgData.media || [];
    if (mediaList.length === 1) {
      bodyText = mediaList[0].isVideo ? "Video" : "Photo";
    } else if (mediaList.length > 1) {
      bodyText = `${mediaList.length} photos`;
    } else {
      bodyText = "Photo";
    }
  } else if (typeof msgData.text === "string") {
    const trimmed = msgData.text.trim();
    bodyText = trimmed.length > 80 ? `${trimmed.substring(0, 77)}...` : trimmed;
  }

  // 9. Send via NotificationService
  await NotificationService.sendToUser(recipient.id, {
    category: "messages",
    type: "chat_message",
    title: senderName,
    body: bodyText,
    data: {
      route: `/chat/${conversationId}`,
      conversationId,
      messageId,
      senderUid: callerFirebaseUid,
    },
    collapseKey: conversationId,
  });

  return { notified: true };
}

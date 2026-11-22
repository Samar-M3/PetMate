import cloudinary from "../../config/cloudinary.ts";
import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import chatConfig from "../../config/chat.config.ts";
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

  return { match, callerFirebaseUid, otherFirebaseUid };
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

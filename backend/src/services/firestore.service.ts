import { FieldValue } from "firebase-admin/firestore";
import { firestore } from "../config/firebase.ts";
import cloudinary from "../config/cloudinary.ts";
import { AppError } from "../middleware/errorHandler.ts";

export interface ConversationDocument {
  matchId: string;
  participantUids: string[];
  status: "ACTIVE" | "ENDED";
  endedReason?: string;
  createdAt: any;
  lastMessage?: {
    text: string;
    senderUid: string;
    type?: string;
  };
  lastMessageAt: any;
  unread: Record<string, number>;
  lastRead: Record<string, any>;
}

export interface MediaItemInput {
  kind: "image" | "video";
  publicId: string;
  format: string;
  bytes: number;
  width: number;
  height: number;
  durationSeconds?: number;
  thumbnailPublicId?: string;
}

export interface ReplyToInput {
  messageId: string;
  senderUid: string;
  type: string;
  preview: string;
}

export const ensureConversation = async (
  matchId: string,
  participantUids: [string, string]
): Promise<void> => {
  try {
    const docRef = firestore.collection("conversations").doc(matchId);
    const existing = await docRef.get();

    if (!existing.exists) {
      const initialUnread: Record<string, number> = {};
      initialUnread[participantUids[0]] = 0;
      initialUnread[participantUids[1]] = 0;

      await docRef.set({
        matchId,
        participantUids,
        status: "ACTIVE",
        createdAt: FieldValue.serverTimestamp(),
        lastMessageAt: FieldValue.serverTimestamp(),
        unread: initialUnread,
        lastRead: {},
      });
    } else {
      const data = existing.data();
      const patch: Record<string, any> = {
        matchId,
        participantUids,
      };
      if (!data?.status) {
        patch.status = "ACTIVE";
      }
      await docRef.set(patch, { merge: true });
    }
  } catch (error) {
    console.error(`[FirestoreService] Failed to ensure conversation for match ${matchId}:`, error);
  }
};

export const endConversation = async (
  matchId: string,
  reason: "UNMATCHED" | "BLOCKED" | "PET_DELETED" | "ACCOUNT_SUSPENDED" | string
): Promise<void> => {
  try {
    const docRef = firestore.collection("conversations").doc(matchId);
    await docRef.set(
      {
        status: "ENDED",
        endedReason: reason,
        endedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (error) {
    console.error(`[FirestoreService] Failed to end conversation for match ${matchId}:`, error);
  }
};

export const deleteConversationCloudinaryAssets = async (conversationId: string): Promise<void> => {
  try {
    await cloudinary.api.delete_resources_by_prefix(`chat/${conversationId}`, {
      type: "authenticated",
      resource_type: "image",
    });
    await cloudinary.api.delete_resources_by_prefix(`chat/${conversationId}`, {
      type: "authenticated",
      resource_type: "video",
    });
    await cloudinary.api.delete_folder(`chat/${conversationId}`);
  } catch (err) {
    // Non-fatal if folder was empty or already cleaned
  }
};

export const deleteConversation = async (matchId: string): Promise<void> => {
  try {
    await deleteConversationCloudinaryAssets(matchId);
    const docRef = firestore.collection("conversations").doc(matchId);
    await firestore.recursiveDelete(docRef);
  } catch (error) {
    console.error(`[FirestoreService] Failed to delete conversation for match ${matchId}:`, error);
  }
};

export const getConversationDoc = async (matchId: string): Promise<ConversationDocument | null> => {
  try {
    const snap = await firestore.collection("conversations").doc(matchId).get();
    if (!snap.exists) return null;
    return snap.data() as ConversationDocument;
  } catch (error) {
    console.error(`[FirestoreService] Failed to get conversation ${matchId}:`, error);
    return null;
  }
};

export const deleteCloudinaryAssets = async (
  publicIds: string[],
  resourceType: "image" | "video" = "image"
): Promise<void> => {
  if (publicIds.length === 0) return;
  try {
    await cloudinary.api.delete_resources(publicIds, {
      resource_type: resourceType,
      type: "authenticated",
    });
  } catch (error) {
    console.error(`[Cloudinary] Failed to delete ${resourceType} assets:`, error);
  }
};

export const createMediaMessage = async (
  conversationId: string,
  clientMessageId: string,
  senderUid: string,
  otherUid: string,
  items: MediaItemInput[],
  caption?: string,
  replyTo?: ReplyToInput
): Promise<any> => {
  const convRef = firestore.collection("conversations").doc(conversationId);
  const msgRef = convRef.collection("messages").doc(clientMessageId);

  // Idempotency: return existing if message with clientMessageId already wrote
  const existing = await msgRef.get();
  if (existing.exists) {
    return existing.data();
  }

  const batch = firestore.batch();

  const cleanItems = items.map((i) => {
    const itemMap: Record<string, any> = {
      kind: i.kind,
      publicId: i.publicId,
      format: i.format,
      bytes: i.bytes,
      width: i.width,
      height: i.height,
    };
    if (i.durationSeconds != null) {
      itemMap.durationSeconds = i.durationSeconds;
    }
    if (i.thumbnailPublicId) {
      itemMap.thumbnailPublicId = i.thumbnailPublicId;
    }
    return itemMap;
  });

  const msgData: Record<string, any> = {
    senderUid,
    type: "media",
    text: caption ? caption.trim() : "",
    media: cleanItems,
    deletedForEveryone: false,
    deletedFor: [],
    mediaExpired: false,
    createdAt: FieldValue.serverTimestamp(),
  };

  if (replyTo) {
    msgData.replyTo = {
      messageId: replyTo.messageId,
      senderUid: replyTo.senderUid,
      type: replyTo.type,
      preview: replyTo.preview.slice(0, 100),
    };
  }

  batch.set(msgRef, msgData);

  // Formulate lastMessage preview
  let preview = "Photo";
  const imageCount = items.filter((i) => i.kind === "image").length;
  const videoCount = items.filter((i) => i.kind === "video").length;

  if (caption && caption.trim()) {
    preview = caption.trim();
  } else if (items.length === 1) {
    preview = items[0].kind === "video" ? "Video" : "Photo";
  } else if (imageCount > 0 && videoCount === 0) {
    preview = `${imageCount} photos`;
  } else if (videoCount > 0 && imageCount === 0) {
    preview = `${videoCount} videos`;
  } else {
    preview = `${items.length} media items`;
  }

  const convUpdate: Record<string, any> = {
    lastMessage: {
      text: preview,
      senderUid,
      type: "media",
    },
    lastMessageAt: FieldValue.serverTimestamp(),
  };

  if (otherUid) {
    convUpdate[`unread.${otherUid}`] = FieldValue.increment(1);
  }

  batch.update(convRef, convUpdate);
  await batch.commit();

  return msgData;
};

export const deleteMessageForEveryone = async (
  conversationId: string,
  messageId: string,
  callerFirebaseUid: string,
  windowMinutes: number
): Promise<{ success: boolean; message: string }> => {
  const convRef = firestore.collection("conversations").doc(conversationId);
  const msgRef = convRef.collection("messages").doc(messageId);

  const msgSnap = await msgRef.get();
  if (!msgSnap.exists) {
    throw new AppError("Message not found", 404);
  }

  const msgData = msgSnap.data()!;
  if (msgData.senderUid !== callerFirebaseUid) {
    throw new AppError("You can only delete your own messages", 403);
  }

  if (msgData.deletedForEveryone) {
    return { success: true, message: "Message already deleted" };
  }

  // Verify deletion window
  if (msgData.createdAt) {
    const createdDate = msgData.createdAt.toDate
      ? msgData.createdAt.toDate()
      : new Date(msgData.createdAt);
    const ageMinutes = (Date.now() - createdDate.getTime()) / (1000 * 60);
    if (ageMinutes > windowMinutes) {
      throw new AppError("Message deletion window has expired", 400);
    }
  }

  // Delete associated Cloudinary assets if it was a media message
  if (msgData.type === "media" && Array.isArray(msgData.media)) {
    const imageIds = msgData.media
      .filter((m: any) => m.kind === "image")
      .map((m: any) => m.publicId);
    const videoIds = msgData.media
      .filter((m: any) => m.kind === "video")
      .map((m: any) => m.publicId);
    const thumbIds = msgData.media
      .filter((m: any) => m.thumbnailPublicId)
      .map((m: any) => m.thumbnailPublicId);

    if (imageIds.length > 0) await deleteCloudinaryAssets(imageIds, "image");
    if (thumbIds.length > 0) await deleteCloudinaryAssets(thumbIds, "image");
    if (videoIds.length > 0) await deleteCloudinaryAssets(videoIds, "video");
  }

  // Update message document to deleted state
  await msgRef.update({
    deletedForEveryone: true,
    deletedAt: FieldValue.serverTimestamp(),
    text: "",
    media: [],
  });

  // Scrub replyTo in replies that quoted this message
  try {
    const quotingSnap = await convRef
      .collection("messages")
      .where("replyTo.messageId", "==", messageId)
      .get();

    if (!quotingSnap.empty) {
      const batch = firestore.batch();
      for (const doc of quotingSnap.docs) {
        batch.update(doc.ref, {
          "replyTo.preview": "Message deleted",
        });
      }
      await batch.commit();
    }
  } catch (err) {
    console.error("[FirestoreService] Failed to scrub quoting replies:", err);
  }

  // If conversation lastMessage was this message, update preview
  try {
    const convSnap = await convRef.get();
    const convData = convSnap.data();
    if (convData?.lastMessage?.senderUid === callerFirebaseUid) {
      await convRef.update({
        "lastMessage.text": "This message was deleted",
      });
    }
  } catch (err) {
    console.error("[FirestoreService] Failed to update conversation lastMessage:", err);
  }

  return { success: true, message: "Message deleted for everyone" };
};

export const cleanupExpiredChatMedia = async (retentionDays: number): Promise<number> => {
  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
  let cleanedCount = 0;

  try {
    const convsSnap = await firestore.collection("conversations").get();
    for (const convDoc of convsSnap.docs) {
      const expiredSnap = await convDoc.ref
        .collection("messages")
        .where("type", "==", "media")
        .where("createdAt", "<=", cutoff)
        .get();

      for (const msgDoc of expiredSnap.docs) {
        const data = msgDoc.data();
        if (data.mediaExpired) continue;

        if (Array.isArray(data.media) && data.media.length > 0) {
          const imageIds = data.media
            .filter((m: any) => m.kind === "image")
            .map((m: any) => m.publicId);
          const videoIds = data.media
            .filter((m: any) => m.kind === "video")
            .map((m: any) => m.publicId);
          if (imageIds.length > 0) await deleteCloudinaryAssets(imageIds, "image");
          if (videoIds.length > 0) await deleteCloudinaryAssets(videoIds, "video");
        }

        await msgDoc.ref.update({
          mediaExpired: true,
          media: [],
        });
        cleanedCount++;
      }
    }
  } catch (error) {
    console.error("[FirestoreService] Error in cleanupExpiredChatMedia:", error);
  }

  return cleanedCount;
};

export const getMessageSnapshot = async (
  conversationId: string,
  messageId?: string
): Promise<any> => {
  try {
    const convRef = firestore.collection("conversations").doc(conversationId);
    if (messageId) {
      const msgSnap = await convRef.collection("messages").doc(messageId).get();
      if (msgSnap.exists) {
        const data = msgSnap.data()!;
        let signedUrls: Record<string, string> = {};
        if (Array.isArray(data.media)) {
          for (const m of data.media) {
            if (m.publicId) {
              signedUrls[m.publicId] = cloudinary.url(m.publicId, {
                type: "authenticated",
                sign_url: true,
                resource_type: m.kind === "video" ? "video" : "image",
                expires_at: Math.floor(Date.now() / 1000) + 3600 * 24 * 7,
              });
            }
          }
        }
        return {
          messageId,
          ...data,
          signedUrls,
        };
      }
    }

    const recentMsgs = await convRef
      .collection("messages")
      .orderBy("createdAt", "desc")
      .limit(10)
      .get();

    return recentMsgs.docs.map((d) => ({
      messageId: d.id,
      ...d.data(),
    }));
  } catch (error) {
    console.error(`[FirestoreService] Failed to get message snapshot for ${conversationId}:`, error);
    return null;
  }
};

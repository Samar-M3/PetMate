import { FieldValue } from "firebase-admin/firestore";
import { firestore } from "../config/firebase.ts";

export interface ConversationDocument {
  matchId: string;
  participantUids: string[];
  status: "ACTIVE" | "ENDED";
  endedReason?: string;
  createdAt: any;
  lastMessage?: {
    text: string;
    senderUid: string;
  };
  lastMessageAt: any;
  unread: Record<string, number>;
  lastRead: Record<string, any>;
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
      // If conversation exists but was ENDED, we keep status or re-merge participant UIDs
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
    // Log error without sensitive data
    console.error(`[FirestoreService] Failed to ensure conversation for match ${matchId}:`, error);
    // Rely on GET /matches/:id/chat to repair
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

export const deleteConversation = async (matchId: string): Promise<void> => {
  try {
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

export const getMessageSnapshot = async (
  conversationId: string,
  messageId?: string
): Promise<any> => {
  try {
    const convRef = firestore.collection("conversations").doc(conversationId);
    if (messageId) {
      const msgSnap = await convRef.collection("messages").doc(messageId).get();
      if (msgSnap.exists) {
        return {
          messageId,
          ...msgSnap.data(),
        };
      }
    }

    // Fetch recent 10 messages as snapshot context
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

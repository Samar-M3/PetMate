import { rtdb } from "../config/firebase.ts";
import { firestore } from "../config/firebase.ts";

let currentRtdb = rtdb;

export function setRtdbForTesting(mock: any) {
  currentRtdb = mock;
}

/**
 * Synchronizes Realtime Database contacts and conversationMembers for an ACTIVE conversation.
 * Written only by the backend (Admin SDK).
 * - contacts/{uidA}/{uidB} = true
 * - contacts/{uidB}/{uidA} = true
 * - conversationMembers/{conversationId}/{uidA} = true
 * - conversationMembers/{conversationId}/{uidB} = true
 */
export async function syncConversationMembersAndContacts(
  conversationId: string,
  participantUids: [string, string] | string[],
): Promise<void> {
  if (!participantUids || participantUids.length < 2) return;
  const [uidA, uidB] = participantUids;
  if (!uidA || !uidB) return;

  try {
    const updates: Record<string, boolean> = {
      [`contacts/${uidA}/${uidB}`]: true,
      [`contacts/${uidB}/${uidA}`]: true,
      [`conversationMembers/${conversationId}/${uidA}`]: true,
      [`conversationMembers/${conversationId}/${uidB}`]: true,
    };
    await currentRtdb.ref().update(updates);
  } catch (error) {
    console.error(`[RTDB] Failed to sync contacts/members for conversation ${conversationId}:`, error);
  }
}

/**
 * Removes Realtime Database contacts and conversationMembers when a conversation ends or is deleted.
 */
export async function removeConversationMembersAndContacts(
  conversationId: string,
  participantUids?: [string, string] | string[],
): Promise<void> {
  try {
    const updates: Record<string, null> = {
      [`conversationMembers/${conversationId}`]: null,
    };

    if (participantUids && participantUids.length >= 2) {
      const [uidA, uidB] = participantUids;
      if (uidA && uidB) {
        updates[`contacts/${uidA}/${uidB}`] = null;
        updates[`contacts/${uidB}/${uidA}`] = null;
      }
    }

    await currentRtdb.ref().update(updates);
  } catch (error) {
    console.error(`[RTDB] Failed to remove contacts/members for conversation ${conversationId}:`, error);
  }
}

/**
 * Idempotently backfills RTDB contacts and conversationMembers for all existing ACTIVE conversations in Firestore.
 */
export async function backfillRtdbContacts(): Promise<{ totalActive: number; synced: number }> {
  const snapshot = await firestore
    .collection("conversations")
    .where("status", "==", "ACTIVE")
    .get();

  let synced = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const uids = data.participantUids;
    if (Array.isArray(uids) && uids.length >= 2) {
      await syncConversationMembersAndContacts(doc.id, [uids[0], uids[1]]);
      synced++;
    }
  }

  return {
    totalActive: snapshot.docs.length,
    synced,
  };
}

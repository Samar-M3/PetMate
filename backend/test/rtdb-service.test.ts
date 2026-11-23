import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import {
  syncConversationMembersAndContacts,
  removeConversationMembersAndContacts,
  setRtdbForTesting,
} from "../src/services/rtdb.service.ts";

describe("RTDB Mirror & Sync Service", () => {
  let lastUpdates: Record<string, any> | null = null;

  beforeEach(() => {
    lastUpdates = null;
    const mockRtdb = {
      ref: () => ({
        update: async (updates: Record<string, any>) => {
          lastUpdates = updates;
          return Promise.resolve();
        },
      }),
    };
    setRtdbForTesting(mockRtdb);
  });

  it("syncConversationMembersAndContacts generates bidirectional contacts and conversationMembers", async () => {
    await syncConversationMembersAndContacts("conv-123", ["uid-alice", "uid-bob"]);

    assert.ok(lastUpdates !== null);
    assert.equal(lastUpdates!["contacts/uid-alice/uid-bob"], true);
    assert.equal(lastUpdates!["contacts/uid-bob/uid-alice"], true);
    assert.equal(lastUpdates!["conversationMembers/conv-123/uid-alice"], true);
    assert.equal(lastUpdates!["conversationMembers/conv-123/uid-bob"], true);
  });

  it("syncConversationMembersAndContacts ignores invalid participant arrays safely", async () => {
    await syncConversationMembersAndContacts("conv-123", ["single-uid"]);
    assert.equal(lastUpdates, null);
  });

  it("removeConversationMembersAndContacts removes conversation and contact keys", async () => {
    await removeConversationMembersAndContacts("conv-123", ["uid-alice", "uid-bob"]);

    assert.ok(lastUpdates !== null);
    assert.equal(lastUpdates!["conversationMembers/conv-123"], null);
    assert.equal(lastUpdates!["contacts/uid-alice/uid-bob"], null);
    assert.equal(lastUpdates!["contacts/uid-bob/uid-alice"], null);
  });
});

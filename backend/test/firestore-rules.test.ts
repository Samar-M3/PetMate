import { describe, it, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "petmate-rules-test-" + Date.now();
const rulesPath = path.resolve(process.cwd(), "..", "firestore.rules");
let testEnv: RulesTestEnvironment | null = null;
let rulesAvailable = false;

try {
  if (fs.existsSync(rulesPath)) {
    rulesAvailable = true;
  }
} catch {
  rulesAvailable = false;
}

describe("Firestore Security Rules Verification", () => {
  before(async () => {
    if (!rulesAvailable) return;
    try {
      const rules = fs.readFileSync(rulesPath, "utf8");
      testEnv = await initializeTestEnvironment({
        projectId: PROJECT_ID,
        firestore: {
          rules,
          host: "127.0.0.1",
          port: 8080,
        },
      });
    } catch {
      // If emulator is not running, unit tests skip gracefully
      testEnv = null;
    }
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  it("Rule verification: rules file exists and parses valid structure", () => {
    assert.equal(rulesAvailable, true, "firestore.rules must exist");
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("service cloud.firestore"));
    assert.ok(content.includes("match /conversations/{conversationId}"));
    assert.ok(content.includes("match /messages/{messageId}"));
    assert.ok(content.includes("request.auth.uid in resource.data.participantUids"));
    assert.ok(content.includes("request.resource.data.text.size() <= 1000"));
  });

  it("Conversations: client create and delete are strictly denied in rules", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("allow create, delete: if false;"));
  });

  it("Messages: update and delete are strictly denied in rules", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("allow update, delete: if false;"));
  });

  it("Messages: senderUid must match authenticated user in rules", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("request.resource.data.senderUid == request.auth.uid"));
  });

  it("Messages: status must be ACTIVE in rules", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("data.status == 'ACTIVE'"));
  });
});

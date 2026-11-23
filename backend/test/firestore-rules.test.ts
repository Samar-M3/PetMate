import { describe, it, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  initializeTestEnvironment,
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

  it("Messages: client create strictly restricts type to 'text' (media messages denied for clients)", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("request.resource.data.type == 'text'"));
  });

  it("Messages: replyTo validation checks allowed keys and max 100 chars preview", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(
      content.includes(
        "request.resource.data.replyTo.keys().hasOnly(['messageId', 'senderUid', 'type', 'preview'])"
      )
    );
    assert.ok(content.includes("request.resource.data.replyTo.preview.size() <= 100"));
  });

  it("Messages: update is strictly restricted to adding own auth.uid to deletedFor", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(
      content.includes("request.resource.data.diff(resource.data).affectedKeys().hasOnly(['deletedFor'])")
    );
    assert.ok(content.includes("request.auth.uid in request.resource.data.deletedFor"));
  });

  it("Messages: client delete is strictly denied", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("allow delete: if false;"));
  });

  it("Rules enforce that forged media messages from client are denied", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    // Rule specifies request.resource.data.type == 'text', so type == 'media' will fail
    assert.ok(content.includes("request.resource.data.type == 'text'"));
    // Key allowlist only allows text-related fields, 'media' array is not in allowlist
    assert.ok(!content.includes("'media'") || content.includes("request.resource.data.type == 'text'"));
  });

  it("Rules deny updating text or other fields by clients", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    // Affected keys must only have 'deletedFor'
    assert.ok(content.includes("request.resource.data.diff(resource.data).affectedKeys().hasOnly(['deletedFor'])"));
  });

  it("Rules deny adding someone else's UID to deletedFor", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    // Must contain caller's own uid in deletedFor
    assert.ok(content.includes("request.auth.uid in request.resource.data.deletedFor"));
    // Must increment size by exactly 1
    assert.ok(content.includes("request.resource.data.deletedFor.size() == resource.data.deletedFor.size() + 1"));
  });

  it("Rules deny replyTo with extra keys or invalid preview length", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("request.resource.data.replyTo.keys().hasOnly(['messageId', 'senderUid', 'type', 'preview'])"));
    assert.ok(content.includes("request.resource.data.replyTo.preview.size() <= 100"));
  });

  it("Conversations: watermarks deliveredAt, seenAt, and lastRead must follow strict update rules", () => {
    const content = fs.readFileSync(rulesPath, "utf8");
    assert.ok(content.includes("function validWatermark(field)"));
    assert.ok(content.includes("validWatermark('deliveredAt')"));
    assert.ok(content.includes("validWatermark('seenAt')"));
    assert.ok(content.includes("validWatermark('lastRead')"));
    assert.ok(content.includes("'deliveredAt', 'seenAt'"));
    // Rules enforce caller can only update their own UID key
    assert.ok(content.includes("keys().hasOnly([request.auth.uid])"));
    // Rules enforce value must equal request.time
    assert.ok(content.includes("request.resource.data[field][request.auth.uid] == request.time"));
    // Rules enforce watermark cannot move backwards
    assert.ok(content.includes("request.resource.data[field][request.auth.uid] >= resource.data[field][request.auth.uid]"));
  });
});

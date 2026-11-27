import { describe, it } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const rulesPath = path.resolve(process.cwd(), "..", "database.rules.json");
const firebaseJsonPath = path.resolve(process.cwd(), "..", "firebase.json");

describe("Realtime Database Security Rules Verification", () => {
  it("database.rules.json exists and contains valid JSON", () => {
    assert.ok(fs.existsSync(rulesPath), "database.rules.json must exist");
    const content = fs.readFileSync(rulesPath, "utf8");
    const json = JSON.parse(content);
    assert.ok(json.rules, "Rules root must contain 'rules'");
  });

  it("firebase.json contains database rules entry", () => {
    assert.ok(fs.existsSync(firebaseJsonPath), "firebase.json must exist");
    const content = fs.readFileSync(firebaseJsonPath, "utf8");
    const json = JSON.parse(content);
    assert.ok(json.database, "firebase.json must contain 'database' entry");
    assert.equal(json.database.rules, "database.rules.json");
  });

  it("does not define chat presence or typing paths", () => {
    const json = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    assert.equal(json.rules.status, undefined);
    assert.equal(json.rules.typing, undefined);
  });

  it("retains server-only chat contacts and conversation membership paths", () => {
    const json = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    assert.equal(json.rules.contacts[".read"], false, "contacts read must be false");
    assert.equal(json.rules.contacts[".write"], false, "contacts write must be false");
    assert.equal(json.rules.conversationMembers[".read"], false, "conversationMembers read must be false");
    assert.equal(json.rules.conversationMembers[".write"], false, "conversationMembers write must be false");
    assert.ok(json.rules.contacts, "contacts tree must remain for server sync");
    assert.ok(json.rules.conversationMembers, "conversationMembers tree must remain for chat authorization");
  });
});

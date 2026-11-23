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

  it("status/{$uid}: readable only by self or contacts, writable only by self", () => {
    const json = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    const statusUid = json.rules.status["$uid"];
    assert.ok(statusUid, "status.$uid rule must exist");

    // Read: auth.uid === $uid || contacts check
    assert.ok(
      statusUid[".read"].includes("auth.uid === $uid") &&
        statusUid[".read"].includes("root.child('contacts').child(auth.uid).child($uid).val() === true"),
      "status read must be restricted to self or contacts"
    );

    // Write: only auth.uid === $uid
    assert.equal(
      statusUid[".write"],
      "auth != null && auth.uid === $uid",
      "status write must be restricted to authenticated self"
    );

    // Child validations
    assert.equal(statusUid.connections["$connId"][".validate"], "newData.val() === true");
    assert.equal(statusUid.lastOnline[".validate"], "newData.isNumber()");
    assert.equal(statusUid.visible[".validate"], "newData.isBoolean()");
  });

  it("typing/{$conversationId}: readable and writable only by conversation members, write only by self", () => {
    const json = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    const typingConv = json.rules.typing["$conversationId"];
    assert.ok(typingConv, "typing.$conversationId rule must exist");

    // Read: must be a member
    assert.ok(
      typingConv[".read"].includes("root.child('conversationMembers').child($conversationId).child(auth.uid).val() === true"),
      "typing read must require conversation membership"
    );

    // Write: only own key and must be a member
    const typingUser = typingConv["$uid"];
    assert.ok(
      typingUser[".write"].includes("auth.uid === $uid") &&
        typingUser[".write"].includes("root.child('conversationMembers').child($conversationId).child(auth.uid).val() === true"),
      "typing write must require authenticated self and conversation membership"
    );
    assert.equal(typingUser[".validate"], "newData.isNumber()", "typing timestamp must be a number");
  });

  it("contacts and conversationMembers: client read and write are completely denied", () => {
    const json = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
    assert.equal(json.rules.contacts[".read"], false, "contacts read must be false");
    assert.equal(json.rules.contacts[".write"], false, "contacts write must be false");
    assert.equal(json.rules.conversationMembers[".read"], false, "conversationMembers read must be false");
    assert.equal(json.rules.conversationMembers[".write"], false, "conversationMembers write must be false");
  });
});

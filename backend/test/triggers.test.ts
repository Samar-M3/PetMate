import { test, describe, beforeEach, after } from "node:test";
import assert from "node:assert/strict";
import prisma from "../src/config/db.ts";
import {
  setMessagingForTesting,
  NotificationService,
} from "../src/services/notification.service.ts";
import { notifyChatMessage } from "../src/modules/chat/chat.service.ts";
import { notifyChatMessageController } from "../src/modules/chat/chat.controller.ts";
import { setRtdbForTesting } from "../src/services/rtdb.service.ts";
import { firestore } from "../src/config/firebase.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("Push Notification Triggers & Chat Notify", () => {
  let mockSentMessages: any[] = [];
  const fakeMessaging = {
    sendEachForMulticast: async (msg: any) => {
      mockSentMessages.push(msg);
      return {
        successCount: 1,
        failureCount: 0,
        responses: [{ success: true }],
      };
    },
  };

  beforeEach(() => {
    mockSentMessages = [];
    setMessagingForTesting(fakeMessaging);
  });

  const createMockReqResNext = (userOverrides?: any, params: any = {}, body: any = {}, firebaseUid?: string) => {
    const req: Partial<AuthenticatedRequest> = {
      headers: {},
      user: userOverrides,
      firebaseUid: firebaseUid ?? userOverrides?.firebaseUid,
      params,
      body,
    };
    const res: any = {
      statusCode: 200,
      status(code: number) {
        this.statusCode = code;
        return this;
      },
      json(data: any) {
        this.body = data;
        return this;
      },
    };
    let nextCalled = false;
    let nextError: any = null;
    const next = (err?: any) => {
      nextCalled = true;
      nextError = err;
    };
    return {
      req: req as AuthenticatedRequest,
      res,
      next,
      getStatus: () => ({ nextCalled, nextError }),
    };
  };

  test("notifyChatMessageController validates authentication & parameters", async () => {
    // 1. Missing authentication
    const { req: unauthReq, res: unauthRes, next: unauthNext, getStatus: getUnauthStatus } =
      createMockReqResNext(undefined, { conversationId: "conv-1" }, { messageId: "msg-1" });
    await notifyChatMessageController(unauthReq, unauthRes, unauthNext);
    assert.equal(getUnauthStatus().nextCalled, true);
    assert.equal(getUnauthStatus().nextError.statusCode, 401);

    // 2. Missing messageId
    const dummyUser = { id: "u-1", firebaseUid: "fb-1" } as any;
    const { req: noMsgReq, res: noMsgRes, next: noMsgNext, getStatus: getNoMsgStatus } =
      createMockReqResNext(dummyUser, { conversationId: "conv-1" }, {});
    await notifyChatMessageController(noMsgReq, noMsgRes, noMsgNext);
    assert.equal(getNoMsgStatus().nextCalled, true);
    assert.equal(getNoMsgStatus().nextError.statusCode, 400);
  });

  test("notifyChatMessage enforces idempotency and ignores repeated calls", async () => {
    const now = Date.now();
    const userSender = await prisma.user.create({
      data: {
        firebaseUid: `fb-sender-${now}`,
        email: `sender-${now}@example.com`,
      },
    });
    const userReceiver = await prisma.user.create({
      data: {
        firebaseUid: `fb-recv-${now}`,
        email: `recv-${now}@example.com`,
      },
    });

    const petA = await prisma.pet.create({
      data: {
        userId: userSender.id,
        name: "SenderPet",
        animalType: "Dog",
        breed: "Golden",
        gender: "MALE",
      },
    });
    const petB = await prisma.pet.create({
      data: {
        userId: userReceiver.id,
        name: "ReceiverPet",
        animalType: "Dog",
        breed: "Poodle",
        gender: "FEMALE",
      },
    });

    const [pAId, pBId] = petA.id < petB.id ? [petA.id, petB.id] : [petB.id, petA.id];
    const match = await prisma.match.create({
      data: {
        petAId: pAId,
        petBId: pBId,
        status: "ACTIVE",
      },
    });

    // Register receiver token
    await NotificationService.registerDeviceToken(userReceiver.id, {
      token: `token-recv-${now}`,
    });

    // Create Firestore conversation and message
    const convRef = firestore.collection("conversations").doc(match.id);
    await convRef.set({
      matchId: match.id,
      participantUids: [userSender.firebaseUid, userReceiver.firebaseUid],
      status: "ACTIVE",
      createdAt: new Date(),
    });

    const msgId = `msg-test-${now}`;
    const msgRef = convRef.collection("messages").doc(msgId);
    await msgRef.set({
      senderUid: userSender.firebaseUid,
      text: "Hello there from test!",
      type: "text",
      createdAt: new Date(),
    });

    try {
      // 1. First notify call -> Sends push & sets notifiedAt
      const res1 = await notifyChatMessage(
        match.id,
        msgId,
        userSender.id,
        userSender.firebaseUid
      );
      assert.equal(res1.notified, true);
      assert.equal(mockSentMessages.length, 1);
      assert.equal(mockSentMessages[0].notification.body, "Hello there from test!");

      // Verify notifiedAt was saved on Firestore document
      const snap = await msgRef.get();
      assert.ok(snap.data()?.notifiedAt);

      // 2. Second notify call for same message -> Idempotent no-op
      const res2 = await notifyChatMessage(
        match.id,
        msgId,
        userSender.id,
        userSender.firebaseUid
      );
      assert.equal(res2.notified, false);
      assert.equal(res2.reason, "Already notified");
      assert.equal(mockSentMessages.length, 1); // No new push sent!
    } finally {
      // Cleanup
      await msgRef.delete();
      await convRef.delete();
      await prisma.match.delete({ where: { id: match.id } });
      await prisma.pet.deleteMany({ where: { id: { in: [petA.id, petB.id] } } });
      await prisma.user.deleteMany({ where: { id: { in: [userSender.id, userReceiver.id] } } });
    }
  });

  test("notifyChatMessage blocks push if user is blocked or conversation is ended", async () => {
    const now = Date.now();
    const userSender = await prisma.user.create({
      data: {
        firebaseUid: `fb-send-blk-${now}`,
        email: `send-blk-${now}@example.com`,
      },
    });
    const userReceiver = await prisma.user.create({
      data: {
        firebaseUid: `fb-recv-blk-${now}`,
        email: `recv-blk-${now}@example.com`,
      },
    });

    const petA = await prisma.pet.create({
      data: {
        userId: userSender.id,
        name: "P1",
        animalType: "Cat",
        breed: "Persian",
        gender: "MALE",
      },
    });
    const petB = await prisma.pet.create({
      data: {
        userId: userReceiver.id,
        name: "P2",
        animalType: "Cat",
        breed: "Siamese",
        gender: "FEMALE",
      },
    });

    const [pAId, pBId] = petA.id < petB.id ? [petA.id, petB.id] : [petB.id, petA.id];
    const match = await prisma.match.create({
      data: {
        petAId: pAId,
        petBId: pBId,
        status: "ACTIVE",
      },
    });

    await NotificationService.registerDeviceToken(userReceiver.id, {
      token: `token-recv-blk-${now}`,
    });

    const convRef = firestore.collection("conversations").doc(match.id);
    await convRef.set({
      matchId: match.id,
      participantUids: [userSender.firebaseUid, userReceiver.firebaseUid],
      status: "ACTIVE",
    });

    const msgId = `msg-blk-${now}`;
    const msgRef = convRef.collection("messages").doc(msgId);
    await msgRef.set({
      senderUid: userSender.firebaseUid,
      text: "Can you see this?",
      type: "text",
    });

    try {
      // 1. Recipient blocks sender in PostgreSQL
      await prisma.userBlock.create({
        data: {
          blockerId: userReceiver.id,
          blockedId: userSender.id,
        },
      });

      const resBlocked = await notifyChatMessage(
        match.id,
        msgId,
        userSender.id,
        userSender.firebaseUid
      );
      assert.equal(resBlocked.notified, false);
      assert.equal(resBlocked.reason, "User is blocked");
      assert.equal(mockSentMessages.length, 0);

      // Remove block and end conversation
      await prisma.userBlock.deleteMany({
        where: { blockerId: userReceiver.id, blockedId: userSender.id },
      });
      await convRef.update({ status: "ENDED", endedReason: "UNMATCHED" });

      const msgId2 = `msg-ended-${now}`;
      const msgRef2 = convRef.collection("messages").doc(msgId2);
      await msgRef2.set({
        senderUid: userSender.firebaseUid,
        text: "After ended",
        type: "text",
      });

      const resEnded = await notifyChatMessage(
        match.id,
        msgId2,
        userSender.id,
        userSender.firebaseUid
      );
      assert.equal(resEnded.notified, false);
      assert.equal(mockSentMessages.length, 0);
      await msgRef2.delete();
    } finally {
      await msgRef.delete();
      await convRef.delete();
      await prisma.userBlock.deleteMany({
        where: {
          OR: [
            { blockerId: userReceiver.id, blockedId: userSender.id },
            { blockerId: userSender.id, blockedId: userReceiver.id },
          ],
        },
      });
      await prisma.match.delete({ where: { id: match.id } });
      await prisma.pet.deleteMany({ where: { id: { in: [petA.id, petB.id] } } });
      await prisma.user.deleteMany({ where: { id: { in: [userSender.id, userReceiver.id] } } });
    }
  });

  test("notifyApplicationStatus sends push notification with system category", async () => {
    const user = await prisma.user.create({
      data: {
        firebaseUid: `fb-app-${Date.now()}`,
        email: `app-${Date.now()}@example.com`,
      },
    });

    try {
      await NotificationService.registerDeviceToken(user.id, {
        token: `token-app-${Date.now()}`,
      });

      const res = await NotificationService.notifyApplicationStatus(
        user.id,
        "SELLER",
        true
      );
      assert.equal(res.sent, true);
      assert.equal(mockSentMessages.length, 1);
      assert.equal(mockSentMessages[0].data.category, "system");
      assert.equal(mockSentMessages[0].data.status, "APPROVED");
    } finally {
      await prisma.user.deleteMany({ where: { id: user.id } });
    }
  });

  after(async () => {
    await prisma.$disconnect();
  });
});

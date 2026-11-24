import { test, describe, beforeEach, after } from "node:test";
import assert from "node:assert/strict";
import prisma from "../src/config/db.ts";
import {
  NotificationService,
  setMessagingForTesting,
  resolveLocalizedText,
  getChannelIdForCategory,
} from "../src/services/notification.service.ts";
import {
  registerDeviceController,
  deleteDeviceController,
  getPreferencesController,
  updatePreferencesController,
} from "../src/modules/notifications/notifications.controller.ts";
import { AppError } from "../src/middleware/errorHandler.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("NotificationService & Endpoints", () => {
  let mockSentMessages: any[] = [];
  let mockSendResponse: any = {
    successCount: 1,
    failureCount: 0,
    responses: [{ success: true }],
  };

  const fakeMessaging = {
    sendEachForMulticast: async (msg: any) => {
      mockSentMessages.push(msg);
      return mockSendResponse;
    },
  };

  beforeEach(() => {
    mockSentMessages = [];
    mockSendResponse = {
      successCount: 1,
      failureCount: 0,
      responses: [{ success: true }],
    };
    setMessagingForTesting(fakeMessaging);
  });

  const createMockReqResNext = (userOverrides?: any, params: any = {}, body: any = {}) => {
    const req: Partial<AuthenticatedRequest> = {
      headers: {},
      user: userOverrides,
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

  test("resolveLocalizedText returns correct locale and fallback", () => {
    assert.equal(resolveLocalizedText("Plain string", "en"), "Plain string");
    assert.equal(resolveLocalizedText("Plain string", "ne"), "Plain string");
    assert.equal(
      resolveLocalizedText({ en: "Hello", ne: "नमस्ते" }, "ne"),
      "नमस्ते"
    );
    assert.equal(
      resolveLocalizedText({ en: "Hello", ne: "नमस्ते" }, "en"),
      "Hello"
    );
    assert.equal(
      resolveLocalizedText({ en: "Hello" }, "ne"),
      "Hello"
    );
  });

  test("getChannelIdForCategory maps correctly to channels", () => {
    assert.equal(getChannelIdForCategory("messages"), "messages");
    assert.equal(getChannelIdForCategory("requests"), "requests_matches");
    assert.equal(getChannelIdForCategory("matches"), "requests_matches");
    assert.equal(getChannelIdForCategory("orders"), "orders");
    assert.equal(getChannelIdForCategory("system"), "system");
  });

  test("Token registration reassigns token and enforces 10 tokens limit", async () => {
    // Create test users
    const userA = await prisma.user.create({
      data: {
        firebaseUid: `test-fcm-a-${Date.now()}`,
        email: `fcm-a-${Date.now()}@example.com`,
      },
    });
    const userB = await prisma.user.create({
      data: {
        firebaseUid: `test-fcm-b-${Date.now()}`,
        email: `fcm-b-${Date.now()}@example.com`,
      },
    });

    try {
      const sharedToken = `token-shared-${Date.now()}`;

      // 1. User A registers the token
      await NotificationService.registerDeviceToken(userA.id, {
        token: sharedToken,
        platform: "android",
        locale: "en",
      });

      let tokenRecord = await prisma.deviceToken.findUnique({
        where: { token: sharedToken },
      });
      assert.equal(tokenRecord?.userId, userA.id);

      // 2. User B registers the same token -> Reassigned to User B
      await NotificationService.registerDeviceToken(userB.id, {
        token: sharedToken,
        platform: "android",
        locale: "ne",
      });

      tokenRecord = await prisma.deviceToken.findUnique({
        where: { token: sharedToken },
      });
      assert.equal(tokenRecord?.userId, userB.id);
      assert.equal(tokenRecord?.locale, "ne");

      // 3. User B registers 12 different tokens -> Max 10 kept (oldest pruned)
      for (let i = 1; i <= 12; i++) {
        await NotificationService.registerDeviceToken(userB.id, {
          token: `token-prune-${i}-${Date.now()}`,
          platform: "android",
        });
      }

      const totalTokens = await prisma.deviceToken.count({
        where: { userId: userB.id },
      });
      assert.equal(totalTokens, 10);
    } finally {
      await prisma.user.deleteMany({
        where: { id: { in: [userA.id, userB.id] } },
      });
    }
  });

  test("sendToUser skips disabled categories and inactive users", async () => {
    const user = await prisma.user.create({
      data: {
        firebaseUid: `test-fcm-pref-${Date.now()}`,
        email: `fcm-pref-${Date.now()}@example.com`,
        isActive: true,
      },
    });

    try {
      await NotificationService.registerDeviceToken(user.id, {
        token: `token-pref-test-${Date.now()}`,
      });

      // Turn off 'orders' and 'showPreviews'
      await NotificationService.updatePreferences(user.id, {
        orders: false,
        showPreviews: false,
      });

      // 1. Send 'orders' notification -> should be skipped
      const orderResult = await NotificationService.sendToUser(user.id, {
        category: "orders",
        type: "order_shipped",
        title: "Order Shipped",
        body: "Your package is on the way",
      });
      assert.equal(orderResult.sent, false);
      assert.equal(mockSentMessages.length, 0);

      // 2. Send 'messages' with showPreviews=false -> body is generic "New message"
      const msgResult = await NotificationService.sendToUser(user.id, {
        category: "messages",
        type: "chat_message",
        title: "Bob",
        body: "Secret private text",
      });
      assert.equal(msgResult.sent, true);
      assert.equal(mockSentMessages.length, 1);
      assert.equal(mockSentMessages[0].notification.body, "New message");

      // 3. Inactive user -> skipped
      await prisma.user.update({
        where: { id: user.id },
        data: { isActive: false },
      });

      const inactiveResult = await NotificationService.sendToUser(user.id, {
        category: "messages",
        type: "chat_message",
        title: "Bob",
        body: "Hello",
      });
      assert.equal(inactiveResult.sent, false);
    } finally {
      await prisma.user.deleteMany({ where: { id: user.id } });
    }
  });

  test("sendToUser prunes invalid tokens based on FCM error code", async () => {
    const user = await prisma.user.create({
      data: {
        firebaseUid: `test-fcm-invalid-${Date.now()}`,
        email: `fcm-invalid-${Date.now()}@example.com`,
      },
    });

    try {
      const invalidToken = `invalid-fcm-token-${Date.now()}`;
      await NotificationService.registerDeviceToken(user.id, {
        token: invalidToken,
      });

      mockSendResponse = {
        successCount: 0,
        failureCount: 1,
        responses: [
          {
            success: false,
            error: { code: "messaging/registration-token-not-registered" },
          },
        ],
      };

      await NotificationService.sendToUser(user.id, {
        category: "system",
        type: "system_announcement",
        title: "Update",
        body: "Please restart app",
      });

      // Token should have been deleted from DB
      const found = await prisma.deviceToken.findUnique({
        where: { token: invalidToken },
      });
      assert.equal(found, null);
    } finally {
      await prisma.user.deleteMany({ where: { id: user.id } });
    }
  });

  test("Endpoints authorization and validation", async () => {
    // 1. Unauthenticated registerDeviceController
    const { req: unauthReq, res: unauthRes, next: unauthNext, getStatus: getUnauthStatus } =
      createMockReqResNext(undefined, {}, { token: "sample-valid-token-12345" });
    await registerDeviceController(unauthReq, unauthRes, unauthNext);
    const { nextCalled: unauthCalled, nextError: unauthError } = getUnauthStatus();
    assert.equal(unauthCalled, true);
    assert.equal(unauthError.statusCode, 401);

    // 2. Invalid token validation
    const dummyUser = { id: "user-123", isActive: true } as any;
    const { req: badTokenReq, res: badTokenRes, next: badTokenNext, getStatus: getBadTokenStatus } =
      createMockReqResNext(dummyUser, {}, { token: "short" });
    await registerDeviceController(badTokenReq, badTokenRes, badTokenNext);
    assert.equal(getBadTokenStatus().nextError.statusCode, 400);

    // 3. Invalid preference field validation
    const { req: badPrefReq, res: badPrefRes, next: badPrefNext, getStatus: getBadPrefStatus } =
      createMockReqResNext(dummyUser, {}, { maliciousField: true });
    await updatePreferencesController(badPrefReq, badPrefRes, badPrefNext);
    assert.equal(getBadPrefStatus().nextError.statusCode, 400);

    // 4. Isolation: deleting a token that does not belong to the user returns removed: false
    const { req: delReq, res: delRes, next: delNext } =
      createMockReqResNext(dummyUser, { token: "token-not-mine-123" });
    await deleteDeviceController(delReq, delRes, delNext);
    assert.equal(delRes.statusCode, 200);
    assert.equal(delRes.body.data.removed, false);
  });

  after(async () => {
    await prisma.$disconnect();
  });
});

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { AppError } from "../src/middleware/errorHandler.ts";
import {
  signatureController,
  mediaMessageController,
  deleteForEveryoneController,
  mediaUrlsController,
} from "../src/modules/chat/chat.controller.ts";
import chatConfig from "../src/config/chat.config.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("Chat Media Endpoints", () => {
  const createMockReqResNext = (
    userOverrides?: any,
    firebaseUid?: string,
    params: any = {},
    body: any = {},
    query: any = {}
  ) => {
    const req: Partial<AuthenticatedRequest> = {
      headers: {},
      user: userOverrides,
      firebaseUid,
      params,
      body,
      query,
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

  describe("signatureController", () => {
    test("rejects unauthenticated caller with 401", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        undefined,
        undefined,
        { conversationId: "conv-1" },
        { kind: "image", mimeType: "image/jpeg", sizeBytes: 1000 }
      );
      await signatureController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 401);
    });

    test("rejects missing body fields with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        {}
      );
      await signatureController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects missing conversationId with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        {},
        { kind: "image", mimeType: "image/jpeg", sizeBytes: 1000 }
      );
      await signatureController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });
  });

  describe("mediaMessageController", () => {
    test("rejects unauthenticated caller with 401", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        undefined,
        undefined,
        { conversationId: "conv-1" },
        { clientMessageId: "msg-1", items: [] }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 401);
    });

    test("rejects missing clientMessageId with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        { items: [{ kind: "image" }] }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects empty items array with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        { clientMessageId: "msg-1", items: [] }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects items exceeding CHAT_MAX_MEDIA_PER_MESSAGE with 400", async () => {
      const tooManyItems = Array.from({ length: chatConfig.CHAT_MAX_MEDIA_PER_MESSAGE + 1 }, (_, i) => ({
        kind: "image",
        publicId: `chat/conv-1/img-${i}`,
      }));
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        { clientMessageId: "msg-1", items: tooManyItems }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects caption exceeding 1000 chars with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        {
          clientMessageId: "msg-1",
          items: [{ kind: "image", publicId: "chat/conv-1/1" }],
          caption: "a".repeat(1001),
        }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects replyTo with preview exceeding 100 chars with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        {
          clientMessageId: "msg-1",
          items: [{ kind: "image", publicId: "chat/conv-1/1" }],
          replyTo: {
            messageId: "orig-1",
            senderUid: "other-user",
            type: "text",
            preview: "p".repeat(101),
          },
        }
      );
      await mediaMessageController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });
  });

  describe("deleteForEveryoneController", () => {
    test("rejects unauthenticated caller with 401", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        undefined,
        undefined,
        { conversationId: "conv-1", messageId: "msg-1" },
        {},
        { scope: "everyone" }
      );
      await deleteForEveryoneController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 401);
    });

    test("rejects non-everyone scope with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1", messageId: "msg-1" },
        {},
        { scope: "me" }
      );
      await deleteForEveryoneController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });
  });

  describe("mediaUrlsController", () => {
    test("rejects unauthenticated caller with 401", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        undefined,
        undefined,
        { conversationId: "conv-1" },
        { publicIds: ["chat/conv-1/1"] }
      );
      await mediaUrlsController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 401);
    });

    test("rejects empty publicIds with 400", async () => {
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        { publicIds: [] }
      );
      await mediaUrlsController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });

    test("rejects more than 50 publicIds with 400", async () => {
      const ids = Array.from({ length: 51 }, (_, i) => `chat/conv-1/id-${i}`);
      const { req, res, next, getStatus } = createMockReqResNext(
        { id: "user-1" },
        "firebase-1",
        { conversationId: "conv-1" },
        { publicIds: ids }
      );
      await mediaUrlsController(req, res, next);
      const { nextCalled, nextError } = getStatus();
      assert.equal(nextCalled, true);
      assert(nextError instanceof AppError);
      assert.equal(nextError.statusCode, 400);
    });
  });
});

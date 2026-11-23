import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { AppError } from "../src/middleware/errorHandler.ts";
import { batchDeleteController } from "../src/modules/chat/chat.controller.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("Batch Delete Controller Security & Validation", () => {
  const createMockReqResNext = (
    userOverrides?: any,
    params: any = {},
    body: any = {},
    firebaseUid?: string,
  ) => {
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

  test("rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(
      undefined,
      { conversationId: "match-1" },
      { messageIds: ["msg-1"], scope: "everyone" },
    );
    await batchDeleteController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("rejects missing messageIds with 400", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(
      { id: "user-1", firebaseUid: "fb-1" },
      { conversationId: "match-1" },
      { scope: "everyone" },
    );
    await batchDeleteController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 400);
    assert.match(nextError.message, /messageIds array is required/);
  });

  test("rejects batch exceeding 50 messages with 400", async () => {
    const messageIds = Array.from({ length: 51 }, (_, i) => `msg-${i}`);
    const { req, res, next, getStatus } = createMockReqResNext(
      { id: "user-1", firebaseUid: "fb-1" },
      { conversationId: "match-1" },
      { messageIds, scope: "everyone" },
    );
    await batchDeleteController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 400);
    assert.match(nextError.message, /Maximum 50 messages/);
  });

  test("rejects non-everyone scope with 400", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(
      { id: "user-1", firebaseUid: "fb-1" },
      { conversationId: "match-1" },
      { messageIds: ["msg-1"], scope: "me" },
    );
    await batchDeleteController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 400);
    assert.match(nextError.message, /Only scope=everyone is supported/);
  });
});

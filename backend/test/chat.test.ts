import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { AppError } from "../src/middleware/errorHandler.ts";
import { reportChatController } from "../src/modules/chat/chat.controller.ts";
import { blockUserController } from "../src/modules/users/users.controller.ts";
import { getMatchChatHandler, unmatchHandler } from "../src/modules/matching/matching.controller.ts";
import { blockUser } from "../src/modules/users/users.service.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("Chat & Match Security Rules", () => {
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

  test("reportChatController rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      conversationId: "match-123",
    }, { reason: "Spam" });
    await reportChatController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("reportChatController rejects missing reason with 400", async () => {
    const { req, res, next, getStatus } = createMockReqResNext({ id: "user-1" }, {
      conversationId: "match-123",
    }, { reason: "   " });
    await reportChatController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 400);
  });

  test("blockUserController rejects unauthenticated caller with 404", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      id: "target-user-123",
    });
    await blockUserController(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 404);
  });

  test("blockUser rejects self-blocking with 400", async () => {
    await assert.rejects(
      async () => {
        await blockUser("same-user-id", "same-user-id");
      },
      (err: any) => {
        return err.statusCode === 400;
      }
    );
  });

  test("getMatchChatHandler rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      id: "match-123",
    });
    await getMatchChatHandler(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("unmatchHandler rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      id: "match-123",
    });
    await unmatchHandler(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });
});

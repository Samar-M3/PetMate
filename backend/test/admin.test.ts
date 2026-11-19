import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  requireRole,
  requireInitializedUser,
  Role,
  type AuthenticatedRequest,
} from "../src/middleware/auth.middleware.ts";
import { initializeUser, updateMe } from "../src/modules/users/users.controller.ts";
import { AppError } from "../src/middleware/errorHandler.ts";

describe("Admin RBAC Middleware Guards", () => {
  const createMockReqResNext = (userOverrides?: any) => {
    const req: Partial<AuthenticatedRequest> = {
      headers: {},
      user: userOverrides,
    };
    const res: any = {
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
    return { req: req as AuthenticatedRequest, res, next, getStatus: () => ({ nextCalled, nextError }) };
  };

  test("No authenticated user gets 401", () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined);
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("PET_OWNER token gets 403 on admin route", () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "user-1",
      role: Role.PET_OWNER,
      isActive: true,
    });
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /insufficient permissions/);
  });

  test("SELLER token gets 403 on admin route", () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "user-seller",
      role: Role.SELLER,
      isActive: true,
    });
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
  });

  test("VETERINARIAN token gets 403 on admin route", () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "user-vet",
      role: Role.VETERINARIAN,
      isActive: true,
    });
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
  });

  test("ADMIN token gets allowed (next without error)", () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "user-admin",
      role: Role.ADMIN,
      isActive: true,
    });
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert.equal(nextError, undefined);
  });

  test("Deactivated ADMIN gets 403", () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "user-admin-deactivated",
      role: Role.ADMIN,
      isActive: false,
    });
    const middleware = requireRole(Role.ADMIN);
    middleware(req, res, next);

    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /deactivated/);
  });
});

describe("Non-Admin Endpoint Hardening (Role Tampering Prevention)", () => {
  test("POST /users/initialize rejects attempts to provide a role", async () => {
    const req: any = {
      firebaseUid: "test-uid",
      body: { role: "ADMIN", phoneNumber: "1234567890" },
    };
    const res: any = {};
    let nextError: any = null;
    const next = (err: any) => {
      nextError = err;
    };

    await initializeUser(req, res, next);

    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /Role cannot be set or updated/);
  });

  test("PUT /users/me rejects attempts to set role", async () => {
    const req: any = {
      user: { id: "user-normal", role: Role.PET_OWNER, isActive: true },
      body: { role: "ADMIN", fullName: "Hacker" },
    };
    const res: any = {};
    let nextError: any = null;
    const next = (err: any) => {
      nextError = err;
    };

    await updateMe(req, res, next);

    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /Role cannot be set or updated/);
  });

  test("PUT /users/me rejects attempts to modify isActive status", async () => {
    const req: any = {
      user: { id: "user-normal", role: Role.PET_OWNER, isActive: true },
      body: { isActive: true, fullName: "Normal User" },
    };
    const res: any = {};
    let nextError: any = null;
    const next = (err: any) => {
      nextError = err;
    };

    await updateMe(req, res, next);

    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /status cannot be modified/);
  });

  test("PUT /users/me rejects disallowed fields via allowlist", async () => {
    const req: any = {
      user: { id: "user-normal", role: Role.PET_OWNER, isActive: true },
      body: { unauthorizedSecretField: "inject", fullName: "Normal User" },
    };
    const res: any = {};
    let nextError: any = null;
    const next = (err: any) => {
      nextError = err;
    };

    await updateMe(req, res, next);

    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 400);
    assert.match(nextError.message, /Invalid field in request body/);
  });
});

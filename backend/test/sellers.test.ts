import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { AppError } from "../src/middleware/errorHandler.ts";
import { Role, StoreStatus } from "../src/generated/prisma/client.ts";
import { validateSellerRegistration } from "../src/modules/sellers/sellers.validation.ts";
import { requireApprovedSeller } from "../src/modules/sellers/sellers.middleware.ts";
import { slugify } from "../src/modules/sellers/sellers.service.ts";
import prisma from "../src/config/db.ts";

describe("Seller Registration Validation", () => {
  const validData = {
    fullName: "Rohan Shakya",
    email: "rohan.seller@example.com",
    phoneNumber: "9841234567",
    password: "Password123!",
    confirmPassword: "Password123!",
    storeName: "Paws & Tails Store",
    businessType: "REGISTERED_BUSINESS",
    description: "Quality accessories and pet health goods",
    businessAddress: "New Road, Ward 22",
    city: "Kathmandu",
    province: "Bagmati",
    postalCode: "44600",
    termsAccepted: true,
  };

  test("Valid input passes validation", () => {
    const validated = validateSellerRegistration(validData);
    assert.equal(validated.fullName, "Rohan Shakya");
    assert.equal(validated.email, "rohan.seller@example.com");
    assert.equal(validated.storeName, "Paws & Tails Store");
    assert.equal(validated.businessType, "REGISTERED_BUSINESS");
  });

  test("Fails if full name is missing or too short", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, fullName: "A" }), {
      name: "Error",
      message: /Full name is required/i,
    });
  });

  test("Fails if email is invalid", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, email: "invalid-email" }), {
      name: "Error",
      message: /valid email address/i,
    });
  });

  test("Fails if password is too short", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, password: "123", confirmPassword: "123" }), {
      name: "Error",
      message: /at least 6 characters/i,
    });
  });

  test("Fails if confirm password does not match", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, confirmPassword: "DifferentPassword!" }), {
      name: "Error",
      message: /does not match/i,
    });
  });

  test("Fails if store name is missing", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, storeName: "" }), {
      name: "Error",
      message: /Store name is required/i,
    });
  });

  test("Fails if terms are not accepted", () => {
    assert.throws(() => validateSellerRegistration({ ...validData, termsAccepted: false }), {
      name: "Error",
      message: /terms and conditions/i,
    });
  });
});

describe("Seller Slug Generation", () => {
  test("Converts store name to clean URL slug", () => {
    assert.equal(slugify("Paws & Tails Store!"), "paws-tails-store");
    assert.equal(slugify("   Kathmandu Pet Supplies   "), "kathmandu-pet-supplies");
  });
});

describe("Seller Dashboard RBAC Middleware Guard", () => {
  const createMockReqResNext = (userOverrides?: any) => {
    const req: any = {
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
    return { req, res, next, getStatus: () => ({ nextCalled, nextError }) };
  };

  test("Unauthenticated user receives 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined);
    await requireApprovedSeller(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("Deactivated user receives 403 suspension", async () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "u1",
      role: Role.SELLER,
      isActive: false,
    });
    await requireApprovedSeller(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /suspended/i);
  });

  test("PET_OWNER receives 403 insufficient permission", async () => {
    const { req, res, next, getStatus } = createMockReqResNext({
      id: "u1",
      role: Role.PET_OWNER,
      isActive: true,
    });
    await requireApprovedSeller(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 403);
    assert.match(nextError.message, /only registered sellers/i);
  });
});

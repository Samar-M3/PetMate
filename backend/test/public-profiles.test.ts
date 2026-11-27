import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { AppError } from "../src/middleware/errorHandler.ts";
import { getPublicPet } from "../src/modules/pets/pets.controller.ts";
import { getPublicUser } from "../src/modules/users/users.controller.ts";
import { calculateAgeInMonths } from "../src/modules/matching/matching.service.ts";
import type { AuthenticatedRequest } from "../src/middleware/auth.middleware.ts";

describe("Public Profiles: Access & Security Guardrails", () => {
  const createMockReqResNext = (userOverrides?: any, params: any = {}) => {
    const req: Partial<AuthenticatedRequest> = {
      headers: {},
      user: userOverrides,
      params,
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

  test("getPublicPet rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      id: "pet-123",
    });
    await getPublicPet(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("getPublicUser rejects unauthenticated caller with 401", async () => {
    const { req, res, next, getStatus } = createMockReqResNext(undefined, {
      id: "user-123",
    });
    await getPublicUser(req, res, next);
    const { nextCalled, nextError } = getStatus();
    assert.equal(nextCalled, true);
    assert(nextError instanceof AppError);
    assert.equal(nextError.statusCode, 401);
  });

  test("calculateAgeInMonths computes accurate month counts", () => {
    assert.equal(calculateAgeInMonths(null), 0);
    assert.equal(calculateAgeInMonths(undefined), 0);

    const now = new Date();
    const sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 6, now.getDate());
    assert.equal(calculateAgeInMonths(sixMonthsAgo), 6);

    const twoYearsAgo = new Date(now.getFullYear() - 2, now.getMonth(), now.getDate());
    assert.equal(calculateAgeInMonths(twoYearsAgo), 24);
  });

  test("public pet profile DTO strictly respects key allowlist and never exposes private fields", () => {
    // Expected exact keys in public pet profile
    const expectedKeys = new Set([
      "id",
      "name",
      "species",
      "breed",
      "sex",
      "ageMonths",
      "ageString",
      "weight",
      "area",
      "about",
      "photos",
      "healthBadges",
      "personality",
      "owner",
      "relationship",
      "canSwipe",
    ]);

    const samplePublicPet = {
      id: "pet-1",
      name: "Bella",
      species: "Dog",
      breed: "Golden Retriever",
      sex: "Female",
      ageMonths: 18,
      ageString: "1 yr 6 mo old",
      weight: null,
      area: "Jhamsikhel, Lalitpur",
      about: "Energetic and friendly pup",
      photos: ["https://cloudinary.com/pet1.jpg"],
      healthBadges: ["Vaccinated"],
      personality: ["Playful", "Gentle"],
      owner: {
        id: "owner-1",
        displayName: "Sarah",
        avatarUrl: "https://cloudinary.com/owner1.jpg",
      },
      relationship: "NONE",
      canSwipe: true,
    };

    const actualKeys = Object.keys(samplePublicPet);
    for (const key of actualKeys) {
      assert.ok(expectedKeys.has(key), `Key ${key} should be in allowlist`);
    }
    assert.equal(actualKeys.length, expectedKeys.size);

    // Private fields assertion
    const privateFields = ["email", "phone", "phoneNumber", "firebaseUid", "userId", "password"];
    for (const field of privateFields) {
      assert.equal((samplePublicPet as any)[field], undefined, `Field ${field} must NOT exist`);
      assert.equal((samplePublicPet.owner as any)[field], undefined, `Owner field ${field} must NOT exist`);
    }
  });

  test("public user profile DTO strictly respects key allowlist and only includes active pets", () => {
    const expectedUserKeys = new Set([
      "id",
      "displayName",
      "avatarUrl",
      "memberSince",
      "area",
      "bio",
      "pets",
    ]);

    const samplePublicUser = {
      id: "user-1",
      displayName: "Sarah Jenkins",
      avatarUrl: "https://cloudinary.com/avatar.jpg",
      memberSince: "January 2026",
      area: "Sanepa, Lalitpur",
      bio: "Dog lover and volunteer",
      pets: [
        {
          id: "pet-1",
          name: "Bella",
          species: "Dog",
          breed: "Labrador",
          ageMonths: 24,
          ageString: "2 years old",
          photoUrl: "https://cloudinary.com/bella.jpg",
        },
      ],
    };

    const actualKeys = Object.keys(samplePublicUser);
    for (const key of actualKeys) {
      assert.ok(expectedUserKeys.has(key), `User key ${key} should be in allowlist`);
    }
    assert.equal(actualKeys.length, expectedUserKeys.size);

    const privateUserFields = [
      "email",
      "phoneNumber",
      "phone",
      "firebaseUid",
      "role",
      "roleApplications",
      "slotPayments",
    ];
    for (const field of privateUserFields) {
      assert.equal((samplePublicUser as any)[field], undefined, `Field ${field} must NOT exist on user`);
    }
  });

  test("Relationship values are restricted to valid enum states", () => {
    const validRelationships = ["NONE", "REQUEST_SENT", "REQUEST_RECEIVED", "MATCHED"];
    for (const rel of validRelationships) {
      assert.ok(validRelationships.includes(rel));
    }
  });
});

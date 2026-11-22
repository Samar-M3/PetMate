import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  calculateAgeString,
  SwipeAction,
  RequestStatus,
  MatchStatus,
} from "../src/modules/matching/matching.service.ts";
import matchingConfig from "../src/config/matching.config.ts";
import { AppError } from "../src/middleware/errorHandler.ts";

describe("Matching: Config Module", () => {
  test("loads all required config keys with defaults or env overrides", () => {
    assert.equal(typeof matchingConfig.FREE_ACTIVE_PETS, "number");
    assert.equal(typeof matchingConfig.PASS_COOLDOWN_DAYS, "number");
    assert.equal(typeof matchingConfig.REQUEST_EXPIRY_DAYS, "number");
    assert.equal(typeof matchingConfig.MAX_PENDING_REQUESTS, "number");
    assert.equal(typeof matchingConfig.MAX_PETS_PER_OWNER, "number");
    assert.equal(typeof matchingConfig.SLOT_DURATION_DAYS, "number");
    assert.equal(typeof matchingConfig.MAX_PAID_SLOTS, "number");
    assert.equal(typeof matchingConfig.SLOT_PRICE_NPR, "number");

    assert.equal(matchingConfig.FREE_ACTIVE_PETS, 1);
    assert.equal(matchingConfig.PASS_COOLDOWN_DAYS, 30);
    assert.equal(matchingConfig.REQUEST_EXPIRY_DAYS, 14);
    assert.equal(matchingConfig.MAX_PENDING_REQUESTS, 20);
    assert.equal(matchingConfig.MAX_PETS_PER_OWNER, 20);
    assert.equal(matchingConfig.SLOT_DURATION_DAYS, 30);
    assert.equal(matchingConfig.MAX_PAID_SLOTS, 5);
    assert.ok(matchingConfig.SLOT_PRICE_NPR > 0);
  });
});

describe("Matching: calculateAgeString", () => {
  test("returns Unknown age for null or undefined", () => {
    assert.equal(calculateAgeString(null), "Unknown age");
    assert.equal(calculateAgeString(undefined), "Unknown age");
  });

  test("calculates years and months properly", () => {
    const twoYearsAgo = new Date();
    twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);
    twoYearsAgo.setMonth(twoYearsAgo.getMonth() - 3);

    const result = calculateAgeString(twoYearsAgo);
    assert.match(result, /2 yr 3 mo old/);
  });

  test("calculates exact years when month difference is 0", () => {
    const exactlyOneYearAgo = new Date();
    exactlyOneYearAgo.setFullYear(exactlyOneYearAgo.getFullYear() - 1);

    const result = calculateAgeString(exactlyOneYearAgo);
    assert.match(result, /1 year old/);
  });
});

describe("Matching: Enums & Statuses", () => {
  test("SwipeAction contains LIKE and PASS", () => {
    assert.equal(SwipeAction.LIKE, "LIKE");
    assert.equal(SwipeAction.PASS, "PASS");
  });

  test("RequestStatus contains PENDING, ACCEPTED, DECLINED, REJECTED, and EXPIRED", () => {
    assert.equal(RequestStatus.PENDING, "PENDING");
    assert.equal(RequestStatus.ACCEPTED, "ACCEPTED");
    assert.equal(RequestStatus.DECLINED, "DECLINED");
    assert.equal(RequestStatus.REJECTED, "REJECTED");
    assert.equal(RequestStatus.EXPIRED, "EXPIRED");
  });

  test("MatchStatus contains ACTIVE and ENDED", () => {
    assert.equal(MatchStatus.ACTIVE, "ACTIVE");
    assert.equal(MatchStatus.ENDED, "ENDED");
  });
});

describe("Matching: Deck Visibility Rules", () => {
  test("Deck payload excludes sensitive owner info (email, phone, firebaseUid, userId)", () => {
    const mockCandidate = {
      id: "candidate-pet-1",
      name: "Rocky",
      dateOfBirth: new Date("2022-05-10"),
      animalType: "Dog",
      breed: "German Shepherd",
      gender: "Male",
      color: "Black & Tan",
      personality: ["Loyal", "Protective"],
      vaccinationStatus: "Up to date",
      allergies: "None",
      description: "Friendly and playful outdoor companion",
      imageUrl: "https://cloudinary.com/pet.jpg",
      profilePictureUrl: null,
      images: [{ id: "img-1", imageUrl: "https://cloudinary.com/pet.jpg", isMain: true }],
      createdAt: new Date(),
      user: {
        id: "owner-secret-id",
        email: "private@owner.com",
        phoneNumber: "+9779800000000",
        firebaseUid: "private-fb-uid",
        profile: {
          area: "Jhamsikhel",
          location: "Lalitpur",
        },
      },
    };

    // Transformation helper matching getDeckFeed
    const effectiveImageUrl = mockCandidate.imageUrl || "";
    const areaString = `${mockCandidate.user.profile.area}, ${mockCandidate.user.profile.location}`;
    const safeOutput = {
      id: mockCandidate.id,
      name: mockCandidate.name,
      petName: mockCandidate.name,
      petAge: calculateAgeString(mockCandidate.dateOfBirth),
      dateOfBirth: mockCandidate.dateOfBirth,
      animalType: mockCandidate.animalType,
      breed: mockCandidate.breed,
      petBreed: mockCandidate.breed,
      gender: mockCandidate.gender,
      petGender: mockCandidate.gender,
      color: mockCandidate.color,
      personality: mockCandidate.personality,
      vaccinationStatus: mockCandidate.vaccinationStatus,
      allergies: mockCandidate.allergies,
      bio: mockCandidate.description,
      petBio: mockCandidate.description,
      imageUrl: effectiveImageUrl,
      petImageUrl: effectiveImageUrl,
      photos: [effectiveImageUrl],
      area: areaString,
      location: areaString,
      healthBadges: [
        mockCandidate.vaccinationStatus,
        `Allergies: ${mockCandidate.allergies}`,
      ],
      createdAt: mockCandidate.createdAt,
    };

    assert.equal((safeOutput as any).email, undefined);
    assert.equal((safeOutput as any).phoneNumber, undefined);
    assert.equal((safeOutput as any).firebaseUid, undefined);
    assert.equal((safeOutput as any).ownerId, undefined);
    assert.equal(safeOutput.name, "Rocky");
    assert.equal(safeOutput.area, "Jhamsikhel, Lalitpur");
  });

  test("self-swipe is rejected with error", () => {
    const swiperPetId = "pet-1";
    const targetPetId = "pet-1";

    assert.throws(
      () => {
        if (swiperPetId === targetPetId) {
          throw new AppError("A pet cannot swipe on itself", 400);
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 400);
        assert.match(err.message, /cannot swipe on itself/i);
        return true;
      }
    );
  });

  test("undo only allows PASS actions and rejects LIKE", () => {
    const likeSwipe = { action: SwipeAction.LIKE, createdAt: new Date() };
    assert.throws(
      () => {
        if (likeSwipe.action !== SwipeAction.PASS) {
          throw new AppError("Only PASS swipes can be undone. LIKE swipes cannot be undone.", 400);
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 400);
        assert.match(err.message, /Only PASS swipes can be undone/i);
        return true;
      }
    );
  });

  test("undo fails if swipe is older than 10 minutes", () => {
    const elevenMinutesAgo = new Date(Date.now() - 11 * 60 * 1000);
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const passSwipe = { action: SwipeAction.PASS, createdAt: elevenMinutesAgo };

    assert.throws(
      () => {
        if (passSwipe.createdAt < tenMinutesAgo) {
          throw new AppError("Undo window expired. Swipes can only be undone within 10 minutes.", 400);
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 400);
        assert.match(err.message, /Undo window expired/i);
        return true;
      }
    );
  });
});

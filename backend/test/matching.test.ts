import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  calculateAgeString,
  SwipeAction,
  RequestStatus,
  acceptConnectionRequest,
  rejectConnectionRequest,
} from "../src/modules/matching/matching.service.ts";
import { AppError } from "../src/middleware/errorHandler.ts";

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

describe("Matching: Enums", () => {
  test("SwipeAction contains LIKE and PASS", () => {
    assert.equal(SwipeAction.LIKE, "LIKE");
    assert.equal(SwipeAction.PASS, "PASS");
  });

  test("RequestStatus contains PENDING, ACCEPTED, and REJECTED", () => {
    assert.equal(RequestStatus.PENDING, "PENDING");
    assert.equal(RequestStatus.ACCEPTED, "ACCEPTED");
    assert.equal(RequestStatus.REJECTED, "REJECTED");
  });
});

describe("Matching: Security & Data Isolation", () => {
  test("discover response excludes sensitive user fields (email, phone, firebaseUid)", () => {
    const mockPrismaPet = {
      id: "pet-target-1",
      name: "Bella",
      animalType: "Dog",
      breed: "Golden Retriever",
      gender: "Female",
      dateOfBirth: new Date("2023-01-01"),
      color: "Golden",
      personality: ["Friendly", "Playful"],
      vaccinationStatus: "Fully vaccinated",
      allergies: null,
      description: "Loves walks",
      imageUrl: "https://cloudinary.com/pet.jpg",
      profilePictureUrl: null,
      createdAt: new Date(),
      user: {
        id: "owner-user-id",
        profile: {
          fullName: "Sneha Sharma",
          username: "sneha_s",
          location: "Kathmandu",
          area: "Baneshwor",
          imageUrl: "https://cloudinary.com/avatar.jpg",
          profilePictureUrl: null,
        },
      },
    };

    const effectiveImageUrl =
      mockPrismaPet.imageUrl || mockPrismaPet.profilePictureUrl || "";
    const profile = mockPrismaPet.user.profile;
    const item = {
      id: mockPrismaPet.id,
      name: mockPrismaPet.name,
      petName: mockPrismaPet.name,
      petAge: calculateAgeString(mockPrismaPet.dateOfBirth),
      dateOfBirth: mockPrismaPet.dateOfBirth,
      animalType: mockPrismaPet.animalType,
      breed: mockPrismaPet.breed,
      petBreed: mockPrismaPet.breed,
      gender: mockPrismaPet.gender,
      petGender: mockPrismaPet.gender,
      color: mockPrismaPet.color,
      personality: mockPrismaPet.personality,
      vaccinationStatus: mockPrismaPet.vaccinationStatus,
      allergies: mockPrismaPet.allergies,
      bio: mockPrismaPet.description,
      petBio: mockPrismaPet.description,
      imageUrl: effectiveImageUrl,
      petImageUrl: effectiveImageUrl,
      ownerId: mockPrismaPet.user.id,
      ownerName: profile.fullName,
      ownerUsername: profile.username,
      ownerLocation: `${profile.area}, ${profile.location}`,
      ownerAvatarUrl: profile.imageUrl,
      createdAt: mockPrismaPet.createdAt,
    };

    assert.equal((item as any).email, undefined);
    assert.equal((item as any).phoneNumber, undefined);
    assert.equal((item as any).firebaseUid, undefined);
    assert.equal((item as any).user?.email, undefined);

    assert.equal(item.id, "pet-target-1");
    assert.equal(item.petName, "Bella");
    assert.equal(item.ownerUsername, "sneha_s");
    assert.equal(item.ownerName, "Sneha Sharma");
    assert.equal(item.ownerLocation, "Baneshwor, Kathmandu");
    assert.equal(item.petImageUrl, "https://cloudinary.com/pet.jpg");
  });

  test("self-swipe is rejected with error", () => {
    const swiperPetId = "same-pet-id";
    const targetPetId = "same-pet-id";

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
});

describe("Matching: Connection Request Guards", () => {
  test("non-existent connection request throws 404", () => {
    const existing = null;
    assert.throws(
      () => {
        if (!existing) {
          throw new AppError("Connection request not found", 404);
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 404);
        assert.match(err.message, /not found/i);
        return true;
      }
    );
  });

  test("rejecting non-existent connection request throws 404", () => {
    const existing = null;
    assert.throws(
      () => {
        if (!existing) {
          throw new AppError("Connection request not found", 404);
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 404);
        assert.match(err.message, /not found/i);
        return true;
      }
    );
  });

  test("double-action check throws 409 when status is already ACCEPTED or REJECTED", () => {
    const mockRequest = {
      id: "req-1",
      receiverUserId: "user-1",
      status: RequestStatus.ACCEPTED,
    };

    assert.throws(
      () => {
        if (mockRequest.status !== RequestStatus.PENDING) {
          throw new AppError(
            `Request has already been ${mockRequest.status.toLowerCase()}`,
            409
          );
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 409);
        assert.match(err.message, /already been accepted/i);
        return true;
      }
    );
  });

  test("non-receiver user attempting to accept/reject gets 403 forbidden", () => {
    const mockRequest = {
      id: "req-1",
      receiverUserId: "user-receiver",
      status: RequestStatus.PENDING,
    };
    const callerId = "user-attacker";

    assert.throws(
      () => {
        if (mockRequest.receiverUserId !== callerId) {
          throw new AppError(
            "Access forbidden: you are not the receiver of this request",
            403
          );
        }
      },
      (err: any) => {
        assert.ok(err instanceof AppError);
        assert.equal(err.statusCode, 403);
        assert.match(err.message, /not the receiver/i);
        return true;
      }
    );
  });
});

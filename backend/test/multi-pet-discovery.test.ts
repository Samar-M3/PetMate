import { test, describe } from "node:test";
import assert from "node:assert/strict";
import prisma from "../src/config/db.ts";
import {
  getDeckFeed,
  recordSwipe,
  SwipeAction,
} from "../src/modules/matching/matching.service.ts";

describe("Multi-Pet Discovery & Active-Pet Identity", () => {
  const ownerA = "owner-a";
  const ownerB = "owner-b";

  const makePet = (overrides: Record<string, any>) => ({
    id: overrides.id,
    userId: overrides.userId,
    name: overrides.name,
    isActive: overrides.isActive ?? false,
    animalType: "Dog",
    species: "DOG",
    speciesOther: null,
    breed: "Golden Retriever",
    gender: "Male",
    dateOfBirth: new Date("2023-01-01"),
    color: "Golden",
    colorCoat: "Golden",
    personality: ["Friendly"],
    temperament: [],
    purpose: "BOTH",
    isNeutered: false,
    weightKg: 20,
    sizeCategory: "MEDIUM",
    vaccinationStatus: "FULL",
    vaccinationLevel: "FULL",
    rabiesVaccineDate: null,
    bio: "Playful",
    city: "Kathmandu",
    district: "Kathmandu",
    description: "Playful dog",
    imageUrl: "https://example.com/pet.jpg",
    profilePictureUrl: null,
    createdAt: new Date("2026-01-01"),
    images: [],
    user: {
      id: overrides.userId,
      isActive: true,
      profile: {
        area: "Jhamsikhel",
        location: "Lalitpur",
        city: "Lalitpur",
        district: "Lalitpur",
        latitude: 27.67,
        longitude: 85.31,
      },
    },
  });

  const bruno = makePet({ id: "pet-bruno", userId: ownerA, name: "Bruno", isActive: true });
  const bella = makePet({ id: "pet-bella", userId: ownerA, name: "Bella", isActive: false });
  const snowy = makePet({ id: "pet-snowy", userId: ownerA, name: "Snowy", isActive: false });
  const max = makePet({ id: "pet-max", userId: ownerB, name: "Max", isActive: true });
  const luna = makePet({ id: "pet-luna", userId: ownerB, name: "Luna", isActive: false });

  const allPets = [bruno, bella, snowy, max, luna];

  test("Scenario A & B & E: Owner B discovers all of Owner A's pets regardless of isActive, and Owner A never sees own pets", async () => {
    let lastFindManyWhere: any = null;
    const origPet = prisma.pet;
    const origPetSwipe = prisma.petSwipe;
    const origConnectionRequest = prisma.connectionRequest;
    const origMatch = prisma.match;

    Object.defineProperty(prisma, "pet", {
      configurable: true,
      value: {
        findFirst: async ({ where }: any) =>
          allPets.find((p) => p.id === where.id && p.userId === where.userId) ?? null,
        findMany: async ({ where }: any) => {
          lastFindManyWhere = where;
          const excludedOwner = where.userId?.not;
          const excludedIds: string[] = where.id?.notIn ?? [];
          return allPets.filter(
            (p) =>
              p.userId !== excludedOwner &&
              !excludedIds.includes(p.id) &&
              p.user.isActive === true
          );
        },
      },
    });
    Object.defineProperty(prisma, "petSwipe", {
      configurable: true,
      value: { findMany: async () => [] },
    });
    Object.defineProperty(prisma, "connectionRequest", {
      configurable: true,
      value: { findMany: async () => [] },
    });
    Object.defineProperty(prisma, "match", {
      configurable: true,
      value: { findMany: async () => [] },
    });

    try {
      // Scenario A: Owner B browses with Max (Bruno is active on Owner A, Bella/Snowy are inactive)
      const feedForB = await getDeckFeed({ userId: ownerB, actingPetId: max.id });
      assert.deepEqual(
        feedForB.pets.map((p: any) => p.id),
        ["pet-bruno", "pet-bella", "pet-snowy"]
      );
      assert.equal(lastFindManyWhere.isActive, undefined);

      // Scenario B: Owner A switches active browsing pet to Bella (even though bella.isActive is false)
      const feedForABella = await getDeckFeed({ userId: ownerA, actingPetId: bella.id });
      assert.deepEqual(
        feedForABella.pets.map((p: any) => p.id),
        ["pet-max", "pet-luna"]
      );

      // Scenario E: Owner A never sees Bruno, Bella, or Snowy regardless of which pet is active
      const feedForABruno = await getDeckFeed({ userId: ownerA, actingPetId: bruno.id });
      for (const p of feedForABruno.pets) {
        assert.ok(!["pet-bruno", "pet-bella", "pet-snowy"].includes(p.id));
      }
    } finally {
      Object.defineProperty(prisma, "pet", { configurable: true, value: origPet });
      Object.defineProperty(prisma, "petSwipe", { configurable: true, value: origPetSwipe });
      Object.defineProperty(prisma, "connectionRequest", {
        configurable: true,
        value: origConnectionRequest,
      });
      Object.defineProperty(prisma, "match", { configurable: true, value: origMatch });
    }
  });

  test("Scenario C & D: Likes from Bella and Bruno preserve exact initiating pet IDs independently", async () => {
    const recordedSwipes: Array<{ swiperPetId: string; targetPetId: string; action: string }> = [];
    const recordedRequests: Array<{ senderPetId: string; receiverPetId: string }> = [];
    const origTx = prisma.$transaction;

    Object.defineProperty(prisma, "$transaction", {
      configurable: true,
      value: async (cb: any) => {
        const tx = {
          pet: {
            findFirst: async ({ where }: any) =>
              allPets.find((p) => p.id === where.id && p.userId === where.userId) ?? null,
            findUnique: async ({ where }: any) =>
              allPets.find((p) => p.id === where.id) ?? null,
          },
          connectionRequest: {
            count: async () => 0,
            findFirst: async () => null,
            upsert: async ({ create }: any) => {
              recordedRequests.push({
                senderPetId: create.senderPetId,
                receiverPetId: create.receiverPetId,
              });
              return { id: `req-${recordedRequests.length}`, ...create };
            },
          },
          petSwipe: {
            findUnique: async () => null,
            create: async ({ data }: any) => {
              recordedSwipes.push({
                swiperPetId: data.swiperPetId,
                targetPetId: data.targetPetId,
                action: data.action,
              });
              return { id: `swipe-${recordedSwipes.length}`, ...data };
            },
          },
          match: {
            upsert: async () => ({ id: "match-1" }),
          },
        };
        return cb(tx);
      },
    });

    try {
      // Scenario C: Bella (even with isActive: false in DB) likes Max
      const resBella = await recordSwipe({
        userId: ownerA,
        petId: bella.id,
        targetPetId: max.id,
        action: SwipeAction.LIKE,
      });
      assert.equal(resBella.status, "recorded");
      assert.equal(recordedSwipes[0].swiperPetId, bella.id);
      assert.equal(recordedRequests[0].senderPetId, bella.id);
      assert.equal(recordedRequests[0].receiverPetId, max.id);

      // Scenario D: Bruno independently likes Luna
      const resBruno = await recordSwipe({
        userId: ownerA,
        petId: bruno.id,
        targetPetId: luna.id,
        action: SwipeAction.LIKE,
      });
      assert.equal(resBruno.status, "recorded");
      assert.equal(recordedSwipes[1].swiperPetId, bruno.id);
      assert.equal(recordedRequests[1].senderPetId, bruno.id);
      assert.equal(recordedRequests[1].receiverPetId, luna.id);

      // Scenario E (self-swipe): Owner A cannot swipe on own pet
      await assert.rejects(
        () =>
          recordSwipe({
            userId: ownerA,
            petId: bruno.id,
            targetPetId: bella.id,
            action: SwipeAction.LIKE,
          }),
        /Cannot swipe on your own pet/
      );
    } finally {
      Object.defineProperty(prisma, "$transaction", { configurable: true, value: origTx });
    }
  });
});

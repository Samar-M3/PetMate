import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { checkPetProfileCompleteness } from "../src/modules/pets/pets.service.ts";
import matchingConfig from "../src/config/matching.config.ts";

describe("Pets: Multi-Pet & Activation Rules", () => {
  test("profile completeness requires name, species, breed, sex, birth date, and at least one photo", () => {
    // 1. Missing everything
    const emptyPet = {};
    const missingAll = checkPetProfileCompleteness(emptyPet);
    assert.deepEqual(missingAll, [
      "name",
      "species (animalType)",
      "breed",
      "sex (gender)",
      "birth date (dateOfBirth)",
      "at least one photo",
    ]);

    // 2. Partial pet
    const partialPet = {
      name: "Buddy",
      animalType: "Dog",
      breed: "Golden Retriever",
    };
    const missingPartial = checkPetProfileCompleteness(partialPet);
    assert.deepEqual(missingPartial, [
      "sex (gender)",
      "birth date (dateOfBirth)",
      "at least one photo",
    ]);

    // 3. Complete pet with imageUrl
    const completePet = {
      name: "Buddy",
      animalType: "Dog",
      breed: "Golden Retriever",
      gender: "Male",
      dateOfBirth: new Date("2023-01-01"),
      imageUrl: "https://cloudinary.com/buddy.jpg",
    };
    const missingComplete = checkPetProfileCompleteness(completePet);
    assert.deepEqual(missingComplete, []);

    // 4. Complete pet with gallery image
    const galleryPet = {
      name: "Luna",
      animalType: "Cat",
      breed: "Siamese",
      gender: "Female",
      dateOfBirth: new Date("2024-03-15"),
      images: [{ imageUrl: "https://cloudinary.com/luna.jpg" }],
    };
    const missingGallery = checkPetProfileCompleteness(galleryPet);
    assert.deepEqual(missingGallery, []);
  });

  test("MAX_PETS_PER_OWNER is configured to 20", () => {
    assert.equal(matchingConfig.MAX_PETS_PER_OWNER, 20);
  });

  test("FREE_ACTIVE_PETS is configured to 1", () => {
    assert.equal(matchingConfig.FREE_ACTIVE_PETS, 1);
  });
});

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  validateCreateVeterinarianAccount,
  validateInitialVeterinarianPassword,
} from "../src/modules/veterinarians/veterinarians.validation.ts";

describe("Veterinarian account validation", () => {
  test("normalizes email and accepts the admin's account/profile fields", () => {
    const account = validateCreateVeterinarianAccount({
      name: "Dr. Sam",
      email: "VET@EXAMPLE.COM",
      password: "TempPass123",
      licenseNumber: "VET-123",
      clinicName: "Pet Clinic",
      specialty: "Surgery",
      address: "Kathmandu",
      fee: "750",
      isAcceptingBookings: false,
    });

    assert.equal(account.email, "vet@example.com");
    assert.equal(account.fee, 750);
    assert.equal(account.isAcceptingBookings, false);
    assert.equal(account.licenseNumber, "VET-123");
  });

  test("rejects weak temporary passwords and malformed email", () => {
    assert.throws(
      () =>
        validateCreateVeterinarianAccount({
          name: "Dr. Sam",
          email: "not-an-email",
          password: "short",
          clinicName: "Pet Clinic",
          specialty: "Surgery",
          address: "Kathmandu",
        }),
      /valid email|at least 8 characters/,
    );
  });

  test("requires a strong replacement password", () => {
    assert.equal(
      validateInitialVeterinarianPassword({ newPassword: "NewPass456" }),
      "NewPass456",
    );
    assert.throws(
      () => validateInitialVeterinarianPassword({ newPassword: "password" }),
      /letter and one number/,
    );
  });

  test("rejects unexpected fields on password setup", () => {
    assert.throws(
      () =>
        validateInitialVeterinarianPassword({
          newPassword: "NewPass456",
          role: "ADMIN",
        }),
      /not allowed/,
    );
  });
});

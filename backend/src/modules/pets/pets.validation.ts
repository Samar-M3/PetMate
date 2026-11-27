import Joi from "joi";
import { AppError } from "../../middleware/errorHandler.ts";
import {
  PetSpecies,
  PetPurpose,
  PetSizeCategory,
  PetVaccinationStatus,
  PetLastCheckup,
} from "../../generated/prisma/client.ts";

export interface PetPhotoInput {
  url: string;
  publicId: string;
  position: number;
  isPrimary?: boolean;
}

export interface CreateOnboardingPetInput {
  name: string;
  species: PetSpecies;
  speciesOther?: string | null;
  breed: string;
  gender: "MALE" | "FEMALE";
  ageYears: number;
  ageMonths: number;
  photos: PetPhotoInput[];
}

export interface PatchPetInput {
  // Page 2 fields (in case user goes back and edits Page 2!)
  name?: string;
  species?: PetSpecies;
  speciesOther?: string | null;
  breed?: string;
  gender?: "MALE" | "FEMALE";
  ageYears?: number;
  ageMonths?: number;
  photos?: PetPhotoInput[];

  // Page 3 fields (Mating Details)
  purpose?: PetPurpose;
  isNeutered?: boolean;
  hasLitters?: boolean | null;
  litterCount?: number | null;
  temperament?: string[];
  weightKg?: number | null;
  sizeCategory?: PetSizeCategory | null;
  colorCoat?: string | null;
  hasPedigree?: boolean;
  pedigreeCertUrl?: string | null;
  bio?: string | null;
  city?: string | null;
  district?: string | null;

  // Page 4 fields (Health and Vet)
  vaccinationStatus?: PetVaccinationStatus;
  rabiesVaccineDate?: Date | null;
  healthNotes?: string | null;
  lastCheckup?: PetLastCheckup | null;
  vetRecordUrls?: string[];

  onboardingStep?: number;
}

const photoSchema = Joi.object({
  url: Joi.string().uri().required(),
  publicId: Joi.string().trim().required(),
  position: Joi.number().integer().min(0).max(10).default(0),
  isPrimary: Joi.boolean().optional(),
});

const createOnboardingPetSchema = Joi.object({
  name: Joi.string().trim().min(1).max(80).required().messages({
    "string.empty": "Pet name is required",
    "any.required": "Pet name is required",
  }),
  species: Joi.string()
    .uppercase()
    .valid(...Object.values(PetSpecies))
    .required()
    .messages({
      "any.only": "Invalid species",
      "any.required": "Species is required",
    }),
  speciesOther: Joi.string()
    .trim()
    .max(60)
    .when("species", {
      is: PetSpecies.OTHER,
      then: Joi.string().trim().min(1).required().messages({
        "string.empty": "Please specify the species name",
        "any.required": "Please specify the species name",
      }),
      otherwise: Joi.allow("", null).optional(),
    }),
  breed: Joi.string().trim().min(1).max(80).required().messages({
    "string.empty": "Breed is required",
    "any.required": "Breed is required",
  }),
  gender: Joi.string()
    .uppercase()
    .valid("MALE", "FEMALE")
    .required()
    .messages({
      "any.only": "Gender must be Male or Female",
      "any.required": "Gender is required",
    }),
  ageYears: Joi.number().integer().min(0).max(30).default(0),
  ageMonths: Joi.number().integer().min(0).max(11).default(0),
  photos: Joi.array().items(photoSchema).min(1).max(6).required().messages({
    "array.min": "Please add at least 1 photo of your pet",
    "array.max": "You can upload up to 6 photos",
  }),
});

const patchPetSchema = Joi.object({
  // Optional Page 2 edits
  name: Joi.string().trim().min(1).max(80).optional(),
  species: Joi.string()
    .uppercase()
    .valid(...Object.values(PetSpecies))
    .optional(),
  speciesOther: Joi.string().trim().max(60).allow("", null).optional(),
  breed: Joi.string().trim().min(1).max(80).optional(),
  gender: Joi.string().uppercase().valid("MALE", "FEMALE").optional(),
  ageYears: Joi.number().integer().min(0).max(30).optional(),
  ageMonths: Joi.number().integer().min(0).max(11).optional(),
  photos: Joi.array().items(photoSchema).min(1).max(6).optional(),

  // Page 3
  purpose: Joi.string()
    .uppercase()
    .valid(...Object.values(PetPurpose))
    .optional(),
  isNeutered: Joi.boolean().optional(),
  hasLitters: Joi.boolean().allow(null).optional(),
  litterCount: Joi.number().integer().min(0).max(50).allow(null).optional(),
  temperament: Joi.array().items(Joi.string().trim().max(40)).max(10).optional(),
  weightKg: Joi.number().positive().max(250).allow(null).optional(),
  sizeCategory: Joi.string()
    .uppercase()
    .valid(...Object.values(PetSizeCategory))
    .allow(null, "")
    .optional(),
  colorCoat: Joi.string().trim().max(80).allow("", null).optional(),
  hasPedigree: Joi.boolean().optional(),
  pedigreeCertUrl: Joi.string().uri().allow("", null).optional(),
  bio: Joi.string().trim().max(150).allow("", null).optional().messages({
    "string.max": "Bio must be 150 characters or fewer",
  }),
  city: Joi.string().trim().max(80).allow("", null).optional(),
  district: Joi.string().trim().max(80).allow("", null).optional(),

  // Page 4
  vaccinationStatus: Joi.string()
    .uppercase()
    .valid(...Object.values(PetVaccinationStatus))
    .optional(),
  rabiesVaccineDate: Joi.date().max("now").allow(null, "").optional().messages({
    "date.max": "Rabies vaccine date cannot be in the future",
  }),
  healthNotes: Joi.string().trim().max(500).allow("", null).optional(),
  lastCheckup: Joi.string()
    .uppercase()
    .valid(...Object.values(PetLastCheckup))
    .allow(null, "")
    .optional(),
  vetRecordUrls: Joi.array().items(Joi.string().uri()).max(3).optional(),

  onboardingStep: Joi.number().integer().min(1).max(4).optional(),
});

export function validateCreateOnboardingPet(body: unknown): CreateOnboardingPetInput {
  const { error, value } = createOnboardingPetSchema.validate(body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const details = error.details.map((d) => d.message.replace(/"/g, ""));
    throw new AppError(details[0] || "Validation failed", 400, details);
  }

  if ((value.ageYears ?? 0) === 0 && (value.ageMonths ?? 0) === 0) {
    throw new AppError(
      "Pet age must be greater than 0 (enter years or months)",
      400,
      ["At least years or months must be greater than 0"]
    );
  }

  return value as CreateOnboardingPetInput;
}

export function validatePatchPet(body: unknown): PatchPetInput {
  const { error, value } = patchPetSchema.validate(body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const details = error.details.map((d) => d.message.replace(/"/g, ""));
    throw new AppError(details[0] || "Validation failed", 400, details);
  }

  if (
    value.ageYears !== undefined &&
    value.ageMonths !== undefined &&
    value.ageYears === 0 &&
    value.ageMonths === 0
  ) {
    throw new AppError("Pet age must be greater than 0", 400);
  }

  return {
    ...value,
    sizeCategory: value.sizeCategory ? value.sizeCategory : null,
    lastCheckup: value.lastCheckup ? value.lastCheckup : null,
    rabiesVaccineDate: value.rabiesVaccineDate ? new Date(value.rabiesVaccineDate) : value.rabiesVaccineDate === null ? null : undefined,
  } as PatchPetInput;
}

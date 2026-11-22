import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

function parseNumber(envVar: string | undefined, defaultValue: number): number {
  if (!envVar || envVar.trim() === "") return defaultValue;
  const parsed = Number(envVar);
  return Number.isNaN(parsed) ? defaultValue : parsed;
}

function parseRequiredNumber(envVar: string | undefined, name: string): number {
  if (!envVar || envVar.trim() === "") {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  const parsed = Number(envVar);
  if (Number.isNaN(parsed) || parsed <= 0) {
    throw new Error(`Environment variable ${name} must be a positive number`);
  }
  return parsed;
}

export interface MatchingConfig {
  FREE_ACTIVE_PETS: number;
  PASS_COOLDOWN_DAYS: number;
  REQUEST_EXPIRY_DAYS: number;
  MAX_PENDING_REQUESTS: number;
  MAX_PETS_PER_OWNER: number;
  SLOT_DURATION_DAYS: number;
  MAX_PAID_SLOTS: number;
  SLOT_PRICE_NPR: number;
}

export const matchingConfig: MatchingConfig = {
  FREE_ACTIVE_PETS: parseNumber(process.env.FREE_ACTIVE_PETS, 1),
  PASS_COOLDOWN_DAYS: parseNumber(process.env.PASS_COOLDOWN_DAYS, 30),
  REQUEST_EXPIRY_DAYS: parseNumber(process.env.REQUEST_EXPIRY_DAYS, 14),
  MAX_PENDING_REQUESTS: parseNumber(process.env.MAX_PENDING_REQUESTS, 20),
  MAX_PETS_PER_OWNER: parseNumber(process.env.MAX_PETS_PER_OWNER, 20),
  SLOT_DURATION_DAYS: parseNumber(process.env.SLOT_DURATION_DAYS, 30),
  MAX_PAID_SLOTS: parseNumber(process.env.MAX_PAID_SLOTS, 5),
  SLOT_PRICE_NPR: parseNumber(process.env.SLOT_PRICE_NPR, 500),
};

export default matchingConfig;

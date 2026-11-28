import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

export interface EnvironmentConfig {
  PORT: number;
  DATABASE_URL: string;
  NODE_ENV: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_CLIENT_EMAIL?: string;
  FIREBASE_PRIVATE_KEY?: string;
  FIREBASE_DATABASE_URL?: string;
  FIREBASE_SERVICE_ACCOUNT_PATH?: string;
  CLOUDINARY_CLOUD_NAME?: string;
  CLOUDINARY_API_KEY?: string;
  CLOUDINARY_API_SECRET?: string;
  RESEND_API_KEY?: string;
  RESEND_FROM_EMAIL: string;
  RESEND_FROM_NAME: string;
}

const isProd = process.env.NODE_ENV === "production";

function required(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function cleanClientEmail(email?: string): string | undefined {
  if (!email) return undefined;
  let cleaned = email.trim();
  if (
    (cleaned.startsWith('"') && cleaned.endsWith('"')) ||
    (cleaned.startsWith("'") && cleaned.endsWith("'"))
  ) {
    cleaned = cleaned.slice(1, -1).trim();
  }
  if (cleaned.endsWith("\\")) {
    cleaned = cleaned.slice(0, -1).trim();
  }
  return cleaned || undefined;
}

function parsePrivateKey(key?: string): string | undefined {
  if (!key) return undefined;
  let cleaned = key.trim();
  // Strip outer quotes if the user wrapped the string in quotes in .env
  if (
    (cleaned.startsWith('"') && cleaned.endsWith('"')) ||
    (cleaned.startsWith("'") && cleaned.endsWith("'"))
  ) {
    cleaned = cleaned.slice(1, -1);
  }
  // Convert escaped newlines into actual newlines
  return cleaned.replace(/\\n/g, "\n");
}

const env: EnvironmentConfig = {
  PORT: Number(process.env.PORT) || 5000,
  DATABASE_URL: required("DATABASE_URL"),
  NODE_ENV: process.env.NODE_ENV || "development",

  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || "petmate-d7a43",
  FIREBASE_CLIENT_EMAIL: cleanClientEmail(process.env.FIREBASE_CLIENT_EMAIL),
  FIREBASE_PRIVATE_KEY: parsePrivateKey(process.env.FIREBASE_PRIVATE_KEY),
  FIREBASE_DATABASE_URL: process.env.FIREBASE_DATABASE_URL || "https://petmate-d7a43-default-rtdb.asia-southeast1.firebasedatabase.app/",
  FIREBASE_SERVICE_ACCOUNT_PATH: process.env.FIREBASE_SERVICE_ACCOUNT_PATH,

  // Cloudinary credentials
  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME,
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY,
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET,

  // Resend transactional email configuration
  RESEND_API_KEY: process.env.RESEND_API_KEY?.trim() || undefined,
  RESEND_FROM_EMAIL: process.env.RESEND_FROM_EMAIL?.trim() || "onboarding@resend.dev",
  RESEND_FROM_NAME: process.env.RESEND_FROM_NAME?.trim() || "PetMate",
};

// Check if credentials are valid non-placeholder values
const hasValidInlineCreds = Boolean(
  env.FIREBASE_PROJECT_ID &&
  env.FIREBASE_CLIENT_EMAIL &&
  env.FIREBASE_PRIVATE_KEY &&
  !env.FIREBASE_PRIVATE_KEY.includes("...") &&
  !env.FIREBASE_CLIENT_EMAIL.includes("xxxx@")
);

if (!hasValidInlineCreds && !env.FIREBASE_SERVICE_ACCOUNT_PATH) {
  if (isProd) {
    throw new Error(
      "Firebase credentials missing: in production, set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY."
    );
  } else {
    console.warn(
      "⚠️ [Config] Firebase Admin credentials in .env are not fully set or contain placeholders. " +
      "The server will run in public verification mode until actual credentials are provided in .env."
    );
  }
}

export default env;

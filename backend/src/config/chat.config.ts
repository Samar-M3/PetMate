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

export interface ChatConfig {
  CHAT_MAX_IMAGE_MB: number;
  CHAT_MAX_VIDEO_MB: number;
  CHAT_MAX_VIDEO_SECONDS: number;
  CHAT_MAX_MEDIA_PER_MESSAGE: number;
  CHAT_IMAGE_TARGET_MB: number;
  CHAT_VIDEO_TARGET_MB: number;
  CHAT_DELETE_FOR_EVERYONE_WINDOW_MINUTES: number;
  CHAT_MEDIA_UPLOADS_PER_HOUR: number;
  CHAT_MEDIA_RETENTION_DAYS: number;
  CLOUDINARY_CHAT_FOLDER: string;
  ALLOWED_IMAGE_MIME_TYPES: string[];
  ALLOWED_VIDEO_MIME_TYPES: string[];
  ALLOWED_IMAGE_FORMATS: string[];
  ALLOWED_VIDEO_FORMATS: string[];
}

export const chatConfig: ChatConfig = {
  CHAT_MAX_IMAGE_MB: parseNumber(process.env.CHAT_MAX_IMAGE_MB, 10),
  CHAT_MAX_VIDEO_MB: parseNumber(process.env.CHAT_MAX_VIDEO_MB, 25),
  CHAT_MAX_VIDEO_SECONDS: parseNumber(process.env.CHAT_MAX_VIDEO_SECONDS, 60),
  CHAT_MAX_MEDIA_PER_MESSAGE: parseNumber(process.env.CHAT_MAX_MEDIA_PER_MESSAGE, 10),
  CHAT_IMAGE_TARGET_MB: parseNumber(process.env.CHAT_IMAGE_TARGET_MB, 1),
  CHAT_VIDEO_TARGET_MB: parseNumber(process.env.CHAT_VIDEO_TARGET_MB, 10),
  CHAT_DELETE_FOR_EVERYONE_WINDOW_MINUTES: parseNumber(
    process.env.CHAT_DELETE_FOR_EVERYONE_WINDOW_MINUTES,
    2880
  ),
  CHAT_MEDIA_UPLOADS_PER_HOUR: parseNumber(process.env.CHAT_MEDIA_UPLOADS_PER_HOUR, 60),
  CHAT_MEDIA_RETENTION_DAYS: parseNumber(process.env.CHAT_MEDIA_RETENTION_DAYS, 90),
  CLOUDINARY_CHAT_FOLDER: process.env.CLOUDINARY_CHAT_FOLDER || "chat",
  ALLOWED_IMAGE_MIME_TYPES: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
    "image/gif",
  ],
  ALLOWED_VIDEO_MIME_TYPES: [
    "video/mp4",
    "video/quicktime",
    "video/webm",
    "video/3gpp",
    "video/x-matroska",
    "video/x-m4v",
  ],
  ALLOWED_IMAGE_FORMATS: ["jpg", "jpeg", "png", "webp", "heic", "heif", "gif"],
  ALLOWED_VIDEO_FORMATS: ["mp4", "mov", "webm", "3gp", "mkv", "m4v"],
};

export default chatConfig;

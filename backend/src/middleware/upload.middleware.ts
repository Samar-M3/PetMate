import type { Request, Response, NextFunction } from "express";
import multer from "multer";
import { AppError } from "./errorHandler.ts";

const ALLOWED_MIME_TYPES = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "application/octet-stream",
];
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

const storage = multer.memoryStorage();

const fileFilter = (
  _req: Request,
  file: Express.Multer.File,
  cb: multer.FileFilterCallback
) => {
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype.toLowerCase())) {
    return cb(
      new AppError(
        "Invalid file type. Only JPEG, PNG, and WebP images are allowed.",
        400
      )
    );
  }
  cb(null, true);
};

const upload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE_BYTES,
  },
  fileFilter,
});

/**
 * Validates actual binary signature (magic bytes) of the uploaded buffer.
 * Supports JPEG, PNG, and WebP.
 */
export function isValidImageMagicBytes(buffer: Buffer): boolean {
  if (!buffer || buffer.length < 12) return false;

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return true;
  }

  // PNG: 89 50 4E 47
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return true;
  }

  // WebP: RIFF (bytes 0-3) and WEBP (bytes 8-11)
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return true;
  }

  return false;
}

/**
 * Express middleware wrapper for single image upload with error handling and magic bytes check.
 * Default multipart field name: "image".
 */
export const handleSingleImageUpload = (fieldName = "image") => {
  const multerSingle = upload.single(fieldName);

  return (req: Request, res: Response, next: NextFunction): void => {
    multerSingle(req, res, (err: unknown) => {
      if (err) {
        if (err instanceof multer.MulterError) {
          if (err.code === "LIMIT_FILE_SIZE") {
            res.status(413).json({
              success: false,
              message: "File too large. Maximum allowed image size is 5 MB.",
            });
            return;
          }
          res.status(400).json({
            success: false,
            message: `Upload error: ${err.message}`,
          });
          return;
        }

        if (err instanceof AppError) {
          res.status(err.statusCode).json({
            success: false,
            message: err.message,
          });
          return;
        }

        res.status(400).json({
          success: false,
          message: err instanceof Error ? err.message : "Failed to process image upload.",
        });
        return;
      }

      if (req.file) {
        // Validate magic bytes
        if (!isValidImageMagicBytes(req.file.buffer)) {
          res.status(400).json({
            success: false,
            message: "Invalid file signature. File contents do not match a valid JPEG, PNG, or WebP image.",
          });
          return;
        }
      }

      next();
    });
  };
};

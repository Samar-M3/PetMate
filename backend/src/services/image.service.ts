import cloudinary from "../config/cloudinary.ts";
import env from "../config/env.ts";
import { AppError } from "../middleware/errorHandler.ts";

export interface UploadImageResult {
  imageUrl: string;
  imagePublicId: string;
}

/**
 * Uploads an in-memory image buffer to Cloudinary using upload_stream.
 * Ensures https secure_url and tracks public_id.
 */
export const uploadImage = (
  buffer: Buffer,
  subFolder: "users" | "pets" | string,
  publicId?: string
): Promise<UploadImageResult> => {
  return new Promise((resolve, reject) => {
    const environment = env.NODE_ENV || "development";
    const folder = `petmate-${environment}/${subFolder}`;

    const options: Record<string, unknown> = {
      folder,
      resource_type: "image",
    };

    if (publicId) {
      options.public_id = publicId;
      options.overwrite = true;
      options.invalidate = true;
    }

    const uploadStream = cloudinary.uploader.upload_stream(
      options,
      (error, result) => {
        if (error || !result) {
          console.error(
            "[ImageService] Cloudinary upload_stream error:",
            error?.message || "Unknown Cloudinary error"
          );
          return reject(
            new AppError(
              "Failed to process image upload. Please verify your storage credentials.",
              500
            )
          );
        }

        resolve({
          imageUrl: result.secure_url,
          imagePublicId: result.public_id,
        });
      }
    );

    uploadStream.end(buffer);
  });
};

/**
 * Deletes an image asset from Cloudinary and invalidates CDN caches.
 */
export const deleteImage = async (publicId?: string | null): Promise<boolean> => {
  if (!publicId || publicId.trim() === "") return false;

  try {
    const result = await cloudinary.uploader.destroy(publicId, {
      invalidate: true,
      resource_type: "image",
    });
    return result.result === "ok";
  } catch (error) {
    console.error(`[ImageService] Error deleting asset '${publicId}':`, error);
    return false;
  }
};

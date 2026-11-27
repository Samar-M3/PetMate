import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { uploadImage as uploadImageStream } from "../../services/image.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const uploadImage = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const folder = (req.body?.folder as string) || (req.query?.folder as string) || "uploads";

    // 1. Preferred: Multipart file upload via multer
    if (req.file && req.file.buffer) {
      const result = await uploadImageStream(req.file.buffer, folder);
      return void sendSuccess(res, {
        statusCode: 200,
        message: "Image uploaded successfully to Cloudinary",
        data: {
          url: result.imageUrl,
          publicId: result.imagePublicId,
          imageUrl: result.imageUrl,
          imagePublicId: result.imagePublicId,
        },
      });
    }

    // 2. Fallback: Base64 string in req.body.image
    const base64Data = req.body?.image;
    if (base64Data && typeof base64Data === "string") {
      const cleaned = base64Data.replace(/^data:image\/[a-z]+;base64,/, "");
      const buffer = Buffer.from(cleaned, "base64");
      const result = await uploadImageStream(buffer, folder);

      return void sendSuccess(res, {
        statusCode: 200,
        message: "Image uploaded successfully to Cloudinary",
        data: {
          url: result.imageUrl,
          publicId: result.imagePublicId,
          imageUrl: result.imageUrl,
          imagePublicId: result.imagePublicId,
        },
      });
    }

    return next(new AppError("No image provided. Upload a file in form-data field 'image' or provide base64.", 400));
  } catch (error) {
    next(error);
  }
};

export const uploadPrivateImage = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const folder = (req.body?.folder as string) || "vet_records";

    if (req.file && req.file.buffer) {
      const result = await uploadImageStream(req.file.buffer, folder, undefined, true);
      return void sendSuccess(res, {
        statusCode: 200,
        message: "Private image uploaded successfully",
        data: {
          url: result.imageUrl,
          publicId: result.imagePublicId,
        },
      });
    }

    return next(new AppError("No image file provided in form-data field 'image'.", 400));
  } catch (error) {
    next(error);
  }
};

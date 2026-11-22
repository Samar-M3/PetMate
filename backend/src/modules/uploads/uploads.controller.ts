import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { generateUploadSignature, uploadBase64Image } from "../../config/cloudinary.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getSignature = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void => {
  try {
    const folder = (req.query.folder as string) || "petmate_uploads";
    const signatureData = generateUploadSignature(folder);

    sendSuccess(res, {
      statusCode: 200,
      message: "Cloudinary upload signature generated",
      data: signatureData,
    });
  } catch (error) {
    next(error);
  }
};

export const uploadImage = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { image, folder } = req.body;
    if (!image || typeof image !== "string") {
      return next(new AppError("Base64 image data is required in the 'image' field", 400));
    }

    const result = await uploadBase64Image(image, folder || "petmate_uploads");

    sendSuccess(res, {
      statusCode: 200,
      message: "Image uploaded successfully to Cloudinary",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

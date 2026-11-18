import { v2 as cloudinary } from "cloudinary";
import env from "./env.ts";

if (env.CLOUDINARY_CLOUD_NAME && env.CLOUDINARY_API_KEY && env.CLOUDINARY_API_SECRET) {
  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });
  console.log("☁️ Cloudinary initialized successfully.");
} else {
  console.warn("⚠️ Cloudinary credentials not fully configured in backend/.env.");
}

export const generateUploadSignature = (folder = "petmate_uploads") => {
  const timestamp = Math.round(new Date().getTime() / 1000);
  const signature = cloudinary.utils.api_sign_request(
    {
      timestamp,
      folder,
    },
    env.CLOUDINARY_API_SECRET || ""
  );

  return {
    timestamp,
    signature,
    folder,
    cloudName: env.CLOUDINARY_CLOUD_NAME,
    apiKey: env.CLOUDINARY_API_KEY,
    uploadUrl: `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/upload`,
  };
};

export const uploadBase64Image = async (base64Data: string, folder = "petmate_uploads") => {
  const result = await cloudinary.uploader.upload(base64Data, {
    folder,
    resource_type: "image",
  });
  return {
    url: result.secure_url,
    publicId: result.public_id,
  };
};

export default cloudinary;

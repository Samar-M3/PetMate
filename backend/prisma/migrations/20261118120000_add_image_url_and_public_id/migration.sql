-- AlterTable profiles
ALTER TABLE "profiles" ADD COLUMN "image_url" TEXT,
ADD COLUMN "image_public_id" TEXT;

-- AlterTable pets
ALTER TABLE "pets" ADD COLUMN "image_url" TEXT,
ADD COLUMN "image_public_id" TEXT;

-- CreateTable pet_images
CREATE TABLE "pet_images" (
    "id" TEXT NOT NULL,
    "pet_id" TEXT NOT NULL,
    "image_url" TEXT NOT NULL,
    "image_public_id" TEXT NOT NULL,
    "is_main" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pet_images_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "pet_images" ADD CONSTRAINT "pet_images_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "pets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

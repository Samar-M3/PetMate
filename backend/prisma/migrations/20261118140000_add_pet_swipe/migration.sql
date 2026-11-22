-- CreateEnum
CREATE TYPE "SwipeAction" AS ENUM ('LIKE', 'PASS');

-- AlterTable
ALTER TABLE "profiles" ADD COLUMN "username" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "profiles_username_key" ON "profiles"("username");

-- CreateTable
CREATE TABLE "pet_swipes" (
    "id" TEXT NOT NULL,
    "swiper_user_id" TEXT NOT NULL,
    "swiper_pet_id" TEXT NOT NULL,
    "target_pet_id" TEXT NOT NULL,
    "target_user_id" TEXT NOT NULL,
    "action" "SwipeAction" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pet_swipes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "pet_swipes_swiper_pet_id_idx" ON "pet_swipes"("swiper_pet_id");

-- CreateIndex
CREATE INDEX "pet_swipes_target_pet_id_idx" ON "pet_swipes"("target_pet_id");

-- CreateIndex
CREATE UNIQUE INDEX "pet_swipes_swiper_pet_id_target_pet_id_key" ON "pet_swipes"("swiper_pet_id", "target_pet_id");

-- AddForeignKey
ALTER TABLE "pet_swipes" ADD CONSTRAINT "pet_swipes_swiper_user_id_fkey" FOREIGN KEY ("swiper_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pet_swipes" ADD CONSTRAINT "pet_swipes_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pet_swipes" ADD CONSTRAINT "pet_swipes_swiper_pet_id_fkey" FOREIGN KEY ("swiper_pet_id") REFERENCES "pets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pet_swipes" ADD CONSTRAINT "pet_swipes_target_pet_id_fkey" FOREIGN KEY ("target_pet_id") REFERENCES "pets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

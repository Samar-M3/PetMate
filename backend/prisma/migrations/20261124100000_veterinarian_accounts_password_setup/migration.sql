ALTER TABLE "users"
ADD COLUMN "must_change_password" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "veterinarians"
ADD COLUMN "user_id" TEXT;

ALTER TABLE "veterinarians"
ADD COLUMN "license_number" TEXT;

CREATE UNIQUE INDEX "veterinarians_user_id_key" ON "veterinarians"("user_id");

ALTER TABLE "veterinarians"
ADD CONSTRAINT "veterinarians_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "veterinarian_password_setups" (
    "user_id" TEXT NOT NULL,
    "temporary_password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "veterinarian_password_setups_pkey" PRIMARY KEY ("user_id")
);

ALTER TABLE "veterinarian_password_setups"
ADD CONSTRAINT "veterinarian_password_setups_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

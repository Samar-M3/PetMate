ALTER TABLE "users"
ADD COLUMN IF NOT EXISTS "must_change_password" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "veterinarians"
ADD COLUMN IF NOT EXISTS "user_id" TEXT;

ALTER TABLE "veterinarians"
ADD COLUMN IF NOT EXISTS "license_number" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "veterinarians_user_id_key"
ON "veterinarians"("user_id");

CREATE TABLE IF NOT EXISTS "veterinarian_password_setups" (
    "user_id" TEXT NOT NULL,
    "temporary_password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "veterinarian_password_setups_pkey" PRIMARY KEY ("user_id")
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'veterinarians_user_id_fkey'
          AND conrelid = '"veterinarians"'::regclass
    ) THEN
        ALTER TABLE "veterinarians"
        ADD CONSTRAINT "veterinarians_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id")
        ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'veterinarian_password_setups_user_id_fkey'
          AND conrelid = '"veterinarian_password_setups"'::regclass
    ) THEN
        ALTER TABLE "veterinarian_password_setups"
        ADD CONSTRAINT "veterinarian_password_setups_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id")
        ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

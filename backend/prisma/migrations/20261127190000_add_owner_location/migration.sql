-- Add privacy-preserving location fields to profiles for Nearby Pet Owners discovery
ALTER TABLE "profiles"
ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS "location_enabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS "location_updated_at" TIMESTAMP(3);

-- Composite index for bounding-box location prefiltering
CREATE INDEX IF NOT EXISTS "profiles_location_enabled_latitude_longitude_idx"
ON "profiles"("location_enabled", "latitude", "longitude");

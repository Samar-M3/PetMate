-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');

-- CreateTable
CREATE TABLE "connection_requests" (
    "id" TEXT NOT NULL,
    "sender_user_id" TEXT NOT NULL,
    "sender_pet_id" TEXT NOT NULL,
    "receiver_user_id" TEXT NOT NULL,
    "receiver_pet_id" TEXT NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "responded_at" TIMESTAMP(3),

    CONSTRAINT "connection_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "connection_requests_receiver_user_id_status_created_at_idx" ON "connection_requests"("receiver_user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "connection_requests_sender_user_id_idx" ON "connection_requests"("sender_user_id");

-- CreateIndex
CREATE INDEX "connection_requests_receiver_user_id_idx" ON "connection_requests"("receiver_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "connection_requests_sender_pet_id_receiver_pet_id_key" ON "connection_requests"("sender_pet_id", "receiver_pet_id");

-- AddForeignKey
ALTER TABLE "connection_requests" ADD CONSTRAINT "connection_requests_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "connection_requests" ADD CONSTRAINT "connection_requests_receiver_user_id_fkey" FOREIGN KEY ("receiver_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "connection_requests" ADD CONSTRAINT "connection_requests_sender_pet_id_fkey" FOREIGN KEY ("sender_pet_id") REFERENCES "pets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "connection_requests" ADD CONSTRAINT "connection_requests_receiver_pet_id_fkey" FOREIGN KEY ("receiver_pet_id") REFERENCES "pets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "ActivitySource" AS ENUM ('MANUAL', 'GITHUB', 'HEALTH');

-- CreateEnum
CREATE TYPE "Provider" AS ENUM ('GITHUB', 'HEALTH');

-- AlterTable
ALTER TABLE "Activity" ADD COLUMN     "externalId" TEXT,
ADD COLUMN     "source" "ActivitySource" NOT NULL DEFAULT 'MANUAL';

-- CreateTable
CREATE TABLE "Integration" (
    "userId" TEXT NOT NULL,
    "provider" "Provider" NOT NULL,
    "externalLogin" TEXT,
    "accessTokenEnc" TEXT,
    "connectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSyncedAt" TIMESTAMP(3),

    CONSTRAINT "Integration_pkey" PRIMARY KEY ("userId","provider")
);

-- CreateTable
CREATE TABLE "Cheer" (
    "eventId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Cheer_pkey" PRIMARY KEY ("eventId","userId")
);

-- CreateIndex
CREATE UNIQUE INDEX "Activity_userId_source_externalId_key" ON "Activity"("userId", "source", "externalId");

-- AddForeignKey
ALTER TABLE "Integration" ADD CONSTRAINT "Integration_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Cheer" ADD CONSTRAINT "Cheer_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Cheer" ADD CONSTRAINT "Cheer_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;


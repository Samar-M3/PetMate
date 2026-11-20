import prisma from "../../config/db.ts";
import { RequestStatus } from "../../generated/prisma/client.ts";

/**
 * Expire any connection requests that are still PENDING but whose expiresAt date has passed.
 * Safe to run both periodically and lazily before reads.
 */
export async function expireOldRequests(): Promise<number> {
  const now = new Date();
  const result = await prisma.connectionRequest.updateMany({
    where: {
      status: RequestStatus.PENDING,
      expiresAt: {
        lt: now,
      },
    },
    data: {
      status: RequestStatus.EXPIRED,
      respondedAt: now,
    },
  });

  return result.count;
}

let schedulerTimer: NodeJS.Timeout | null = null;

/**
 * Initialize background interval for expiring old requests.
 * Runs every 10 minutes.
 */
export function startRequestExpiryScheduler(intervalMs = 10 * 60 * 1000): void {
  if (schedulerTimer) return;
  // Run once immediately on start
  expireOldRequests().catch((err) => {
    console.error("[ExpiryScheduler] Error running initial request expiration:", err);
  });

  schedulerTimer = setInterval(() => {
    expireOldRequests().catch((err) => {
      console.error("[ExpiryScheduler] Error running request expiration interval:", err);
    });
  }, intervalMs);

  if (schedulerTimer.unref) {
    schedulerTimer.unref();
  }
}

export function stopRequestExpiryScheduler(): void {
  if (schedulerTimer) {
    clearInterval(schedulerTimer);
    schedulerTimer = null;
  }
}

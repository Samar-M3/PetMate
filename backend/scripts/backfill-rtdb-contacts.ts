import { backfillRtdbContacts } from "../src/services/rtdb.service.ts";

async function main() {
  console.log("🔄 Starting RTDB contacts and conversationMembers backfill...");
  try {
    const result = await backfillRtdbContacts();
    console.log(
      `✅ RTDB backfill completed successfully: ${result.synced} of ${result.totalActive} active conversations mirrored.`
    );
    process.exit(0);
  } catch (err) {
    console.error("❌ RTDB backfill failed:", err);
    process.exit(1);
  }
}

main();

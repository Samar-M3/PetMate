import { firestore, timedFirebase } from "../src/config/firebase.ts";

async function ping() {
  console.log("🔍 Testing Firestore Admin connection...");
  const start = performance.now();

  try {
    console.log("1. Testing read with limit(1)...");
    const readStart = performance.now();
    const snapshot = await firestore.collection("conversations").limit(1).get();
    const readDuration = (performance.now() - readStart).toFixed(1);
    console.log(`✅ Read successful in ${readDuration}ms (docs found: ${snapshot.size})`);

    console.log("2. Testing write/delete on test document...");
    const writeStart = performance.now();
    const testDoc = firestore.collection("_health_pings").doc("test-ping");
    await testDoc.set({ ping: true, timestamp: new Date().toISOString() });
    await testDoc.delete();
    const writeDuration = (performance.now() - writeStart).toFixed(1);
    console.log(`✅ Write/delete successful in ${writeDuration}ms`);

    const totalDuration = (performance.now() - start).toFixed(1);
    console.log(`🎉 Total Firestore ping duration: ${totalDuration}ms`);
    process.exit(0);
  } catch (err: any) {
    const totalDuration = (performance.now() - start).toFixed(1);
    console.error(`❌ Firestore ping failed after ${totalDuration}ms:`, err);
    process.exit(1);
  }
}

ping();

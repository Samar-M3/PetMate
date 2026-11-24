import { initializeApp, getApps, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { getDatabase, type Database } from "firebase-admin/database";
import env from "./env.ts";

let firebaseApp: App;

try {
  const existingApps = getApps();
  if (existingApps.length > 0) {
    firebaseApp = existingApps[0]!;
  } else {
    const projectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
    firebaseApp = initializeApp({
      projectId,
      databaseURL: env.FIREBASE_DATABASE_URL,
    });
    console.log(`🔥 Firebase Admin initialized with projectId '${projectId}' (public key verification mode).`);
  }
} catch (error) {
  console.error("❌ Failed to initialize Firebase Admin SDK:", error);
  const fallbackProjectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
  firebaseApp = getApps().length > 0
    ? getApps()[0]!
    : initializeApp({ projectId: fallbackProjectId, databaseURL: env.FIREBASE_DATABASE_URL });
}

export const firebaseAuth: Auth = getAuth(firebaseApp);
export const firestore: Firestore = getFirestore(firebaseApp);
try {
  firestore.settings({ ignoreUndefinedProperties: true });
} catch (_) {}

let _rtdb: Database | null = null;
export const getRtdb = (): Database => {
  if (!_rtdb) {
    _rtdb = getDatabase(firebaseApp);
  }
  return _rtdb;
};

export const rtdb: Database = new Proxy({} as Database, {
  get: (_target, prop) => {
    const db = getRtdb();
    const val = (db as any)[prop];
    return typeof val === "function" ? val.bind(db) : val;
  },
});

export default firebaseApp;

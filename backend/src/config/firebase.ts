import { initializeApp, getApps, cert, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { getDatabase, type Database } from "firebase-admin/database";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import fs from "node:fs";
import path from "node:path";
import env from "./env.ts";

let firebaseApp: App;

const isPlaceholderKey = (key?: string) => {
  if (!key) return true;
  return key.includes("...") || !key.includes("BEGIN PRIVATE KEY");
};

const isPlaceholderEmail = (email?: string) => {
  if (!email) return true;
  return email.includes("xxxx@") || email.includes("your-project");
};

try {
  const existingApps = getApps();
  if (existingApps.length > 0) {
    firebaseApp = existingApps[0]!;
  } else if (env.FIREBASE_SERVICE_ACCOUNT_PATH && fs.existsSync(env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
    const serviceAccount = JSON.parse(fs.readFileSync(env.FIREBASE_SERVICE_ACCOUNT_PATH, "utf-8"));
    firebaseApp = initializeApp({
      credential: cert(serviceAccount),
      databaseURL: env.FIREBASE_DATABASE_URL,
    });
    console.log("🔥 Firebase Admin initialized with service account file.");
  } else if (
    env.FIREBASE_CLIENT_EMAIL &&
    env.FIREBASE_PRIVATE_KEY &&
    !isPlaceholderKey(env.FIREBASE_PRIVATE_KEY) &&
    !isPlaceholderEmail(env.FIREBASE_CLIENT_EMAIL)
  ) {
    try {
      firebaseApp = initializeApp({
        credential: cert({
          projectId: env.FIREBASE_PROJECT_ID || "petmate-d7a43",
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey: env.FIREBASE_PRIVATE_KEY,
        }),
        databaseURL: env.FIREBASE_DATABASE_URL,
      });
      console.log("🔥 Firebase Admin initialized with credentials from .env.");
    } catch (certError) {
      console.error("❌ Failed to parse Firebase private key from .env:", certError);
      const projectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
      firebaseApp = initializeApp({ projectId, databaseURL: env.FIREBASE_DATABASE_URL });
      console.warn(`⚠️ Falling back to public projectId mode: ${projectId}`);
    }
  } else {
    const localKeyPath = path.resolve(process.cwd(), "serviceAccountKey.json");
    if (fs.existsSync(localKeyPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(localKeyPath, "utf-8"));
      firebaseApp = initializeApp({
        credential: cert(serviceAccount),
        databaseURL: env.FIREBASE_DATABASE_URL,
      });
      console.log("🔥 Firebase Admin initialized with local serviceAccountKey.json.");
    } else {
      const projectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
      firebaseApp = initializeApp({ projectId, databaseURL: env.FIREBASE_DATABASE_URL });
      console.warn(
        `⚠️ Firebase Admin initialized with projectId '${projectId}' (public token verification mode). ` +
        `To enable full admin operations, paste your real private key and client email into backend/.env`
      );
    }
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
firestore.settings({ ignoreUndefinedProperties: true });

let _messaging: Messaging | null = null;
export const getMessagingInstance = (): Messaging => {
  if (!_messaging) {
    _messaging = getMessaging(firebaseApp);
  }
  return _messaging;
};

export const messaging: Messaging = new Proxy({} as Messaging, {
  get: (_target, prop) => {
    const m = getMessagingInstance();
    const val = (m as any)[prop];
    return typeof val === "function" ? val.bind(m) : val;
  },
});

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

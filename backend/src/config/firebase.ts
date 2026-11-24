import { initializeApp, getApps, cert, type App, type AppOptions } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { getDatabase, type Database } from "firebase-admin/database";

import { getMessaging, type Messaging } from "firebase-admin/messaging";
import fs from "node:fs";
import path from "node:path";
import env from "./env.ts";

let firebaseApp: App;

try {
  const existingApps = getApps();
  if (existingApps.length > 0) {
    firebaseApp = existingApps[0]!;
  } else {
    const projectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
    const appOptions: AppOptions = {
      projectId,
      databaseURL: env.FIREBASE_DATABASE_URL,
    };

    if (env.FIREBASE_SERVICE_ACCOUNT_PATH && fs.existsSync(env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
      const serviceAccount = JSON.parse(fs.readFileSync(env.FIREBASE_SERVICE_ACCOUNT_PATH, "utf8"));
      appOptions.credential = cert(serviceAccount);
      console.log(`🔥 Firebase Admin initialized with service account file (${env.FIREBASE_SERVICE_ACCOUNT_PATH}).`);
    } else if (
      env.FIREBASE_CLIENT_EMAIL &&
      env.FIREBASE_PRIVATE_KEY &&
      !env.FIREBASE_PRIVATE_KEY.includes("...") &&
      !env.FIREBASE_CLIENT_EMAIL.includes("xxxx@")
    ) {
      appOptions.credential = cert({
        projectId,
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
        privateKey: env.FIREBASE_PRIVATE_KEY,
      });
      console.log(`🔥 Firebase Admin initialized with service account credentials for project '${projectId}' (${env.FIREBASE_CLIENT_EMAIL}).`);
    } else {
      console.log(`🔥 Firebase Admin initialized with projectId '${projectId}' (public key verification mode - missing service account credentials).`);
    }

    firebaseApp = initializeApp(appOptions);
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
firestore.settings({ ignoreUndefinedProperties: true, preferRest: true });

export const timedFirebase = async <T>(
  operationName: string,
  fn: () => Promise<T>,
  timeoutMs = 5000
): Promise<T> => {
  const start = performance.now();
  let timer: NodeJS.Timeout;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new Error(`[Timeout] Firebase operation '${operationName}' exceeded ${timeoutMs}ms limit`));
    }, timeoutMs);
  });

  try {
    const result = await Promise.race([fn(), timeoutPromise]);
    const duration = (performance.now() - start).toFixed(1);
    const flag = Number(duration) > 500 ? " ⚠️ [FIREBASE SLOW >500ms]" : "";
    console.log(`[Firebase] ${operationName} finished in ${duration}ms${flag}`);
    return result;
  } catch (error: any) {
    const duration = (performance.now() - start).toFixed(1);
    console.error(`[Firebase] ❌ ${operationName} failed after ${duration}ms:`, error?.message || error);
    throw error;
  } finally {
    clearTimeout(timer!);
  }
};

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

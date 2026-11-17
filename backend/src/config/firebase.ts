import { initializeApp, getApps, cert, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import fs from "node:fs";
import path from "node:path";
import env from "./env.ts";

let firebaseApp: App;

try {
  const existingApps = getApps();
  if (existingApps.length > 0) {
    firebaseApp = existingApps[0]!;
  } else if (env.FIREBASE_SERVICE_ACCOUNT_PATH && fs.existsSync(env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
    const serviceAccount = JSON.parse(fs.readFileSync(env.FIREBASE_SERVICE_ACCOUNT_PATH, "utf-8"));
    firebaseApp = initializeApp({
      credential: cert(serviceAccount),
    });
    console.log("🔥 Firebase Admin initialized with service account file.");
  } else if (env.FIREBASE_PROJECT_ID && env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
    firebaseApp = initializeApp({
      credential: cert({
        projectId: env.FIREBASE_PROJECT_ID,
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
        privateKey: env.FIREBASE_PRIVATE_KEY,
      }),
    });
    console.log("🔥 Firebase Admin initialized with environment credentials.");
  } else {
    const localKeyPath = path.resolve(process.cwd(), "serviceAccountKey.json");
    if (fs.existsSync(localKeyPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(localKeyPath, "utf-8"));
      firebaseApp = initializeApp({
        credential: cert(serviceAccount),
      });
      console.log("🔥 Firebase Admin initialized with local serviceAccountKey.json.");
    } else {
      const projectId = env.FIREBASE_PROJECT_ID || "petmate-d7a43";
      firebaseApp = initializeApp({ projectId });
      console.warn(
        `⚠️ Firebase Admin initialized with projectId '${projectId}' (public token verification mode). For administrative operations, provide serviceAccountKey.json.`
      );
    }
  }
} catch (error) {
  console.error("❌ Failed to initialize Firebase Admin SDK:", error);
}

export const firebaseAuth: Auth = getAuth();
export default firebaseApp!;

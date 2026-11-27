import express, { type Request, type Response, type NextFunction } from "express";
import cors from "cors";
import authRoutes from "./modules/auth/auth.routes.ts";
import usersRoutes from "./modules/users/users.routes.ts";
import profileRoutes from "./modules/profile/profile.routes.ts";
import petsRoutes from "./modules/pets/pets.routes.ts";
import uploadsRoutes from "./modules/uploads/uploads.routes.ts";
import shopRoutes from "./modules/shop/shop.routes.ts";
import adminRoutes from "./modules/admin/admin.routes.ts";
import matchingRoutes from "./modules/matching/matching.routes.ts";
import slotsRoutes from "./modules/slots/slots.routes.ts";
import chatRoutes from "./modules/chat/chat.routes.ts";
import eventsRoutes from "./modules/events/events.routes.ts";
import veterinariansRoutes from "./modules/veterinarians/veterinarians.routes.ts";
import sellersRoutes from "./modules/sellers/sellers.routes.ts";
import appointmentsRoutes from "./modules/appointments/appointments.routes.ts";
import { devicesRouter, notificationsRouter } from "./modules/notifications/notifications.routes.ts";
import ownersRoutes from "./modules/owners/owners.routes.ts";
import { errorHandler, AppError } from "./middleware/errorHandler.ts";
import { sendSuccess } from "./utils/apiResponse.ts";

import prisma, { queryContext, type RequestQueryContext } from "./config/db.ts";

const app = express();

app.use(
  cors({
    origin: true,
    credentials: true,
    allowedHeaders: ["Content-Type", "Authorization", "Accept", "Origin", "X-Requested-With"],
    methods: ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"],
  })
);
app.use(express.json({ limit: "15mb" }));
app.use(express.urlencoded({ extended: true, limit: "15mb" }));

// Request Timing & Diagnostics Middleware (Task A: duration, status, query count, flag >500ms)
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = performance.now();
  const store: RequestQueryContext = { queryCount: 0, queries: [] };

  queryContext.run(store, () => {
    res.on("finish", () => {
      const durationMs = (performance.now() - start).toFixed(1);
      const isSlow = Number(durationMs) > 500;
      const slowFlag = isSlow ? " ⚠️ [SLOW >500ms]" : "";
      const queriesDetail = store.queryCount > 0 ? ` (${store.queries.slice(0, 5).join(", ")}${store.queries.length > 5 ? "..." : ""})` : "";
      console.log(
        `[Express] ${req.method} ${req.originalUrl} -> ${res.statusCode} | ${durationMs}ms | Prisma queries: ${store.queryCount}${queriesDetail}${slowFlag}`
      );
    });
    next();
  });
});

// Health Check with Database Latency
const healthHandler = async (req: Request, res: Response) => {
  const start = performance.now();
  let dbStatus = "UP";
  let dbLatencyMs = "0.0";
  try {
    await prisma.$queryRaw`SELECT 1 as ping`;
    dbLatencyMs = (performance.now() - start).toFixed(2);
  } catch (err: any) {
    dbStatus = `DOWN: ${err.message}`;
  }

  sendSuccess(res, {
    message: "PetMate Backend API is running healthy",
    data: {
      status: dbStatus === "UP" ? "UP" : "DEGRADED",
      auth: "Firebase Authentication",
      database: "PostgreSQL",
      dbStatus,
      dbLatencyMs: `${dbLatencyMs}ms`,
      timestamp: new Date().toISOString(),
    },
  });
};

app.get("/health", healthHandler);
app.get("/api/health", healthHandler);
app.get("/api/v1/health", healthHandler);

// Feature Routes (support both /api and /api/v1 prefixes)
app.use("/api/auth", authRoutes);
app.use("/api/v1/auth", authRoutes);

app.use("/api/users", usersRoutes);
app.use("/api/v1/users", usersRoutes);

app.use("/api/owners", ownersRoutes);
app.use("/api/v1/owners", ownersRoutes);

app.use("/api/profile", profileRoutes);
app.use("/api/v1/profile", profileRoutes);

app.use("/api/pets", petsRoutes);
app.use("/api/v1/pets", petsRoutes);

app.use("/api/uploads", uploadsRoutes);
app.use("/api/v1/uploads", uploadsRoutes);

app.use("/api/shop", shopRoutes);
app.use("/api/v1/shop", shopRoutes);

app.use("/api/admin", adminRoutes);
app.use("/api/v1/admin", adminRoutes);

app.use("/api/sellers", sellersRoutes);
app.use("/api/v1/sellers", sellersRoutes);

app.use("/api/active-slots", slotsRoutes);
app.use("/api/v1/active-slots", slotsRoutes);

app.use("/api/chats", chatRoutes);
app.use("/api/v1/chats", chatRoutes);

app.use("/api/events", eventsRoutes);
app.use("/api/v1/events", eventsRoutes);

app.use("/api/veterinarians", veterinariansRoutes);
app.use("/api/v1/veterinarians", veterinariansRoutes);

app.use("/api/appointments", appointmentsRoutes);
app.use("/api/v1/appointments", appointmentsRoutes);

app.use("/api/devices", devicesRouter);
app.use("/api/v1/devices", devicesRouter);

app.use("/api/notifications", notificationsRouter);
app.use("/api/v1/notifications", notificationsRouter);

app.use("/api", matchingRoutes);
app.use("/api/v1", matchingRoutes);

// Catch-all 404
app.use((req: Request, res: Response, next: NextFunction) => {
  next(new AppError(`Route not found: ${req.method} ${req.originalUrl}`, 404));
});

// Centralized Error Handler
app.use(errorHandler);

export default app;

import express, { type Request, type Response, type NextFunction } from "express";
import cors from "cors";
import usersRoutes from "./modules/users/users.routes.ts";
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
import { errorHandler, AppError } from "./middleware/errorHandler.ts";
import { sendSuccess } from "./utils/apiResponse.ts";

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

// Request Logging Middleware for Real-time Diagnostics
app.use((req: Request, res: Response, next: NextFunction) => {
  const timestamp = new Date().toISOString().substring(11, 19);
  console.log(`[Express ${timestamp}] 📥 ${req.method} ${req.originalUrl} (from ${req.ip})`);
  next();
});

// Health Check
const healthHandler = (req: Request, res: Response) => {
  sendSuccess(res, {
    message: "PetMate Backend API is running healthy",
    data: {
      status: "UP",
      auth: "Firebase Authentication",
      database: "PostgreSQL",
      timestamp: new Date().toISOString(),
    },
  });
};

app.get("/health", healthHandler);
app.get("/api/health", healthHandler);
app.get("/api/v1/health", healthHandler);

// Feature Routes (support both /api and /api/v1 prefixes)
app.use("/api/users", usersRoutes);
app.use("/api/v1/users", usersRoutes);

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

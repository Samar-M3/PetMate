import express from "express";
import cors from "cors";
import authRoutes from "./modules/auth/auth.routes.js";
import { errorHandler, AppError } from "./middleware/errorHandler.js";
import { sendSuccess } from "./utils/apiResponse.js";

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Base Health Check
app.get("/api/v1/health", (req, res) => {
  sendSuccess(res, {
    message: "PetMate API is running healthy",
    data: {
      status: "UP",
      timestamp: new Date().toISOString(),
    },
  });
});

// Feature Routes
app.use("/api/v1/auth", authRoutes);

// 404 Route Handler
app.use((req, res, next) => {
  next(new AppError(`Route not found: ${req.method} ${req.originalUrl}`, 404));
});

// Centralized Error Handling Middleware
app.use(errorHandler);

export default app;

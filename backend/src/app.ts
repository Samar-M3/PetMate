import express, { type Request, type Response, type NextFunction } from "express";
import cors from "cors";
import authRoutes from "./modules/auth/auth.routes.ts";
import { errorHandler, AppError } from "./middleware/errorHandler.ts";
import { sendSuccess } from "./utils/apiResponse.ts";

const app = express();

app.use(cors());
app.use(express.json());

app.get("/api/v1/health", (req: Request, res: Response) => {
  sendSuccess(res, {
    message: "PetMate API is running healthy",
    data: {
      status: "UP",
      timestamp: new Date().toISOString(),
    },
  });
});

app.use("/api/v1/auth", authRoutes);

app.use((req: Request, res: Response, next: NextFunction) => {
  next(new AppError(`Route not found: ${req.method} ${req.originalUrl}`, 404));
});

app.use(errorHandler);

export default app;

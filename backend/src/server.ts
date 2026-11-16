import app from "./app.ts";
import env from "./config/env.ts";

const PORT = env.PORT || 5000;

const server = app.listen(PORT, () => {
  console.log(`🚀 PetMate TypeScript Backend Server running on port ${PORT} [${env.NODE_ENV}]`);
  console.log(`👉 Health check: http://localhost:${PORT}/api/v1/health`);
  console.log(`👉 Auth endpoints: http://localhost:${PORT}/api/v1/auth`);
});

process.on("SIGINT", () => {
  console.log("Shutting down PetMate backend gracefully...");
  server.close(() => {
    process.exit(0);
  });
});

process.on("SIGTERM", () => {
  console.log("PetMate backend terminated.");
  server.close(() => {
    process.exit(0);
  });
});

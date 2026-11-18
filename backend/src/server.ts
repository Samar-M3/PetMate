import app from "./app.ts";
import env from "./config/env.ts";

const PORT = env.PORT || 5000;

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 PetMate TypeScript Backend Server running on port ${PORT} [${env.NODE_ENV}]`);
  console.log(`👉 Local: http://localhost:${PORT}/api/health`);
  console.log(`👉 Network (LAN): http://10.10.9.90:${PORT}/api/health`);
  console.log(`👉 Users API: http://localhost:${PORT}/api/users`);
  console.log(`👉 Pets API: http://localhost:${PORT}/api/pets`);
  console.log(`👉 Uploads API: http://localhost:${PORT}/api/uploads`);
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

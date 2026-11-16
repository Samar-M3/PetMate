import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "./generated/prisma/client.ts";

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});

const prisma = new PrismaClient({ adapter });

try {
  const result = await prisma.$queryRaw`SELECT 1`;

  console.log("Database connected successfully!");
  console.log(result);
} catch (error) {
  console.error("Database connection failed:", error.message);
} finally {
  await prisma.$disconnect();
}
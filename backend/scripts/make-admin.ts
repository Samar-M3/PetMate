/**
 * Bootstrap script: Promote a user to ADMIN by email.
 * Usage: npm run make-admin -- <email>
 */
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient, Role } from "../src/generated/prisma/client.ts";
import env from "../src/config/env.ts";

async function main() {
  const email = process.argv[2];

  if (!email) {
    console.error("Usage: npm run make-admin -- <email>");
    process.exit(1);
  }

  const adapter = new PrismaPg({ connectionString: env.DATABASE_URL });
  const prisma = new PrismaClient({ adapter });

  try {
    const user = await prisma.user.findFirst({
      where: { email: { equals: email, mode: "insensitive" } },
    });

    if (!user) {
      console.error(`❌ No user found with email: ${email}`);
      process.exit(1);
    }

    if (user.role === Role.ADMIN) {
      console.log(`✅ User ${email} is already an ADMIN.`);
      return;
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { role: Role.ADMIN },
    });

    console.log(`✅ User ${email} has been promoted to ADMIN.`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});

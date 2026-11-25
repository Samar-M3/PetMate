import { AsyncLocalStorage } from "node:async_hooks";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client.ts";
import env from "./env.ts";
import pg from "pg";

export interface RequestQueryContext {
  queryCount: number;
  queries: string[];
}

export const queryContext = new AsyncLocalStorage<RequestQueryContext>();

const { Pool } = pg;

// Dedicated pg.Pool with explicit pool limits to prevent connection starvation
export const pgPool = new Pool({
  connectionString: env.DATABASE_URL,
  max: 20, // Increase pool size from default 10 to 20 for concurrent requests
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000, // 5s timeout on acquiring connection to avoid indefinite stalls
});

pgPool.on("error", (err) => {
  console.error("[PgPool] Unexpected error on idle client:", err.message);
});

const adapter = new PrismaPg(pgPool);

const basePrisma = new PrismaClient({ adapter });

const extendedPrisma = basePrisma.$extends({
  query: {
    $allModels: {
      async $allOperations({ operation, model, args, query }) {
        const store = queryContext.getStore();
        if (store) {
          store.queryCount++;
          store.queries.push(`${model}.${operation}`);
        }
        return query(args);
      },
    },
  },
});

export default extendedPrisma as unknown as typeof basePrisma;

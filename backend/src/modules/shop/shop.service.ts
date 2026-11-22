import { Prisma } from "../../generated/prisma/client.ts";
import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type { ProductListQuery } from "./shop.validation.ts";

const publicProductWhere: Prisma.ProductWhereInput = {
  status: "ACTIVE",
  store: { status: "APPROVED" },
};

const productRelations = {
  images: { orderBy: { displayOrder: "asc" as const } },
  category: true,
  store: { select: { id: true, name: true, slug: true, imageUrl: true, status: true } },
  variants: { orderBy: { optionKey: "asc" as const } },
};

const stockWhere: Prisma.ProductWhereInput = {
  OR: [
    { variants: { some: { isAvailable: true, availableStock: { gt: 0 } } } },
    { variants: { none: {} }, availableStock: { gt: 0 } },
  ],
};

const buildWhere = (query: ProductListQuery): Prisma.ProductWhereInput => {
  const and: Prisma.ProductWhereInput[] = [];
  if (query.search) {
    and.push({
      OR: [
        { name: { contains: query.search, mode: "insensitive" } },
        { brand: { contains: query.search, mode: "insensitive" } },
        { description: { contains: query.search, mode: "insensitive" } },
        { category: { name: { contains: query.search, mode: "insensitive" } } },
      ],
    });
  }
  if (query.minPrice !== undefined) {
    and.push({ OR: [{ discountedPrice: { gte: query.minPrice } }, { discountedPrice: null, basePrice: { gte: query.minPrice } }] });
  }
  if (query.maxPrice !== undefined) {
    and.push({ OR: [{ discountedPrice: { lte: query.maxPrice } }, { discountedPrice: null, basePrice: { lte: query.maxPrice } }] });
  }
  return {
    ...publicProductWhere,
    ...(query.categoryId ? { categoryId: query.categoryId } : {}),
    ...(query.brand ? { brand: { contains: query.brand, mode: "insensitive" as const } } : {}),
    ...(and.length ? { AND: and } : {}),
  };
};

const withDiscount = <T extends { basePrice: Prisma.Decimal; discountedPrice: Prisma.Decimal | null }>(product: T) => ({
  ...product,
  discountPercentage: product.discountedPrice
    ? Math.round((1 - Number(product.discountedPrice) / Number(product.basePrice)) * 100)
    : null,
});

const sortOrder = (sortBy: ProductListQuery["sortBy"]): Prisma.ProductOrderByWithRelationInput[] => {
  return [{ createdAt: "desc" }];
};

export const getCategories = () => prisma.category.findMany({
  where: { parentId: null },
  orderBy: { name: "asc" },
  include: {
    children: { orderBy: { name: "asc" }, include: { _count: { select: { products: { where: publicProductWhere } } } } },
    _count: { select: { products: { where: publicProductWhere } } },
  },
});

export const getCategory = async (id: string) => {
  const category = await prisma.category.findUnique({
    where: { id },
    include: {
      children: { orderBy: { name: "asc" }, include: { _count: { select: { products: { where: publicProductWhere } } } } },
      _count: { select: { products: { where: publicProductWhere } } },
    },
  });
  if (!category) throw new AppError("Category not found", 404);
  return category;
};

export const listProducts = async (query: ProductListQuery) => {
  const where = buildWhere(query);
  const [total, brands] = await Promise.all([
    prisma.product.count({ where }),
    prisma.product.findMany({ where: publicProductWhere, distinct: ["brand"], select: { brand: true }, orderBy: { brand: "asc" } }),
  ]);
  let rows;
  if (query.sortBy === "newest") {
    rows = await prisma.product.findMany({
      where, include: productRelations, orderBy: sortOrder(query.sortBy),
      skip: (query.page - 1) * query.limit, take: query.limit,
    });
  } else {
    const search = query.search ? `%${query.search}%` : null;
    const brand = query.brand ? `%${query.brand}%` : null;
    const minimum = query.minPrice ?? null;
    const maximum = query.maxPrice ?? null;
    const direction = query.sortBy === "price_asc" ? Prisma.sql`ASC` : Prisma.sql`DESC`;
    const orderedIds = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      SELECT p.id
      FROM products p
      JOIN stores s ON s.id = p.store_id
      JOIN categories c ON c.id = p.category_id
      WHERE p.status = 'ACTIVE' AND s.status = 'APPROVED'
        AND (${query.categoryId ?? null}::text IS NULL OR p.category_id = ${query.categoryId ?? null})
        AND (${brand}::text IS NULL OR p.brand ILIKE ${brand})
        AND (${search}::text IS NULL OR p.name ILIKE ${search} OR p.brand ILIKE ${search} OR p.description ILIKE ${search} OR c.name ILIKE ${search})
        AND (${minimum}::numeric IS NULL OR COALESCE(p.discounted_price, p.base_price) >= ${minimum})
        AND (${maximum}::numeric IS NULL OR COALESCE(p.discounted_price, p.base_price) <= ${maximum})
      ORDER BY COALESCE(p.discounted_price, p.base_price) ${direction}, p.id ${direction}
      LIMIT ${query.limit} OFFSET ${(query.page - 1) * query.limit}
    `);
    const ids = orderedIds.map((row) => row.id);
    const found = ids.length ? await prisma.product.findMany({ where: { id: { in: ids } }, include: productRelations }) : [];
    const byId = new Map(found.map((row) => [row.id, row]));
    rows = ids.map((id) => byId.get(id)).filter((row): row is NonNullable<typeof row> => row !== undefined);
  }
  return { items: rows.map(withDiscount), brands: brands.map((row) => row.brand).filter((brand): brand is string => Boolean(brand)), page: query.page, limit: query.limit, total, totalPages: Math.ceil(total / query.limit) };
};

export const getFeaturedProducts = async (limit: number) => {
  const rows = await prisma.product.findMany({
    where: { ...publicProductWhere, isFeatured: true }, include: productRelations,
    orderBy: { createdAt: "desc" }, take: limit,
  });
  return rows.map(withDiscount);
};

export const getNewArrivals = async (limit: number) => {
  const rows = await prisma.product.findMany({
    where: publicProductWhere, include: productRelations,
    orderBy: { createdAt: "desc" }, take: limit,
  });
  return rows.map(withDiscount);
};

export const getRecommendedProducts = async (limit: number) => {
  const rows = await prisma.product.findMany({
    where: { ...publicProductWhere, ...stockWhere, isFeatured: true }, include: productRelations,
    orderBy: { createdAt: "desc" }, take: limit,
  });
  if (rows.length >= limit) return rows.map(withDiscount);
  const recent = await prisma.product.findMany({
    where: { ...publicProductWhere, ...stockWhere, id: { notIn: rows.map((item) => item.id) } },
    include: productRelations, orderBy: { createdAt: "desc" }, take: limit - rows.length,
  });
  return [...rows, ...recent].map(withDiscount);
};

export const getProduct = async (id: string) => {
  const row = await prisma.product.findFirst({ where: { id, ...publicProductWhere }, include: productRelations });
  if (!row) throw new AppError("Product not found", 404);
  return {
    ...withDiscount(row),
    available: row.variants.length > 0
      ? row.variants.some((variant) => variant.isAvailable && variant.availableStock > 0)
      : row.availableStock > 0,
  };
};

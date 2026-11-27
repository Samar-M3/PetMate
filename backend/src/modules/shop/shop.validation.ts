import { AppError } from "../../middleware/errorHandler.ts";

export type ProductSort = "price_asc" | "price_desc" | "newest";
export interface ProductListQuery {
  categoryId?: string;
  search?: string;
  brand?: string;
  minPrice?: number;
  maxPrice?: number;
  sortBy: ProductSort;
  page: number;
  limit: number;
}

const stringValue = (value: unknown, name: string): string | undefined => {
  if (value === undefined) return undefined;
  if (typeof value !== "string" || !value.trim()) throw new AppError(`${name} must be a non-empty string`, 400);
  return value.trim();
};

const numberValue = (value: unknown, name: string): number | undefined => {
  if (value === undefined) return undefined;
  const parsed = typeof value === "number" || typeof value === "string" ? Number(value) : NaN;
  if (!Number.isFinite(parsed) || parsed < 0) throw new AppError(`${name} must be a non-negative number`, 400);
  return parsed;
};

export const parseProductListQuery = (raw: Record<string, unknown>): ProductListQuery => {
  const sortBy = raw.sortBy ?? "newest";
  if (sortBy !== "price_asc" && sortBy !== "price_desc" && sortBy !== "newest") {
    throw new AppError("sortBy must be price_asc, price_desc, or newest", 400);
  }
  const page = raw.page === undefined ? 1 : Number(raw.page);
  const limit = raw.limit === undefined ? 20 : Number(raw.limit);
  if (!Number.isInteger(page) || page < 1) throw new AppError("page must be a positive integer", 400);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new AppError("limit must be an integer between 1 and 100", 400);
  }
  const minPrice = numberValue(raw.minPrice, "minPrice");
  const maxPrice = numberValue(raw.maxPrice, "maxPrice");
  if (minPrice !== undefined && maxPrice !== undefined && minPrice > maxPrice) {
    throw new AppError("minPrice cannot exceed maxPrice", 400);
  }
  return {
    categoryId: stringValue(raw.categoryId, "categoryId"),
    search: stringValue(raw.search, "search"),
    brand: stringValue(raw.brand, "brand"),
    minPrice,
    maxPrice,
    sortBy,
    page,
    limit,
  };
};

const objectBody = (body: unknown): Record<string, unknown> => {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new AppError("Request body must be an object", 400);
  return body as Record<string, unknown>;
};

export const parseAddCartItemBody = (body: unknown) => {
  const input = objectBody(body);
  const productId = stringValue(input.productId, "productId");
  if (!productId) throw new AppError("productId is required", 400);
  const variantId = stringValue(input.variantId, "variantId");
  const quantity = input.quantity === undefined ? 1 : Number(input.quantity);
  if (!Number.isInteger(quantity) || quantity < 1) throw new AppError("quantity must be a positive integer", 400);
  return { productId, variantId, quantity };
};

export const parseUpdateCartItemBody = (body: unknown): number => {
  const quantity = objectBody(body).quantity;
  if (!Number.isInteger(quantity) || Number(quantity) < 1) throw new AppError("quantity must be a positive integer", 400);
  return Number(quantity);
};

export const parseWishlistBody = (body: unknown): string => {
  const productId = stringValue(objectBody(body).productId, "productId");
  if (!productId) throw new AppError("productId is required", 400);
  return productId;
};

export const parseCreateOrderBody = (body: unknown) => {
  const input = objectBody(body);
  const deliveryAddressId = stringValue(input.deliveryAddressId, "deliveryAddressId");
  const fullName = stringValue(input.fullName, "fullName");
  const phoneNumber = stringValue(input.phoneNumber, "phoneNumber");
  const deliveryAddress = stringValue(input.deliveryAddress, "deliveryAddress");
  const landmark = stringValue(input.landmark, "landmark");
  const deliveryInstructions = stringValue(input.deliveryInstructions, "deliveryInstructions");
  const idempotencyKey = stringValue(input.idempotencyKey, "idempotencyKey");
  const paymentMethod = stringValue(input.paymentMethod, "paymentMethod");
  const customerNotes = stringValue(input.customerNotes, "customerNotes");

  if (!deliveryAddressId && (!fullName || !phoneNumber || !deliveryAddress)) {
    throw new AppError("Please provide delivery details (fullName, phoneNumber, deliveryAddress) or select a saved address", 400);
  }

  return {
    deliveryAddressId,
    fullName,
    phoneNumber,
    deliveryAddress,
    landmark,
    deliveryInstructions,
    idempotencyKey,
    paymentMethod,
    customerNotes,
  };
};

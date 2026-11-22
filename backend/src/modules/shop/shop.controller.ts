import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import {
  addCartItem,
  addWishlistItem,
  clearCart,
  getCartForUser,
  getWishlistForUser,
  removeCartItem,
  removeWishlistItem,
  updateCartItem,
} from "./shop.customer.service.ts";
import {
  getCategories,
  getCategory,
  getFeaturedProducts,
  getNewArrivals,
  getProduct,
  getRecommendedProducts,
  listProducts,
} from "./shop.service.ts";
import {
  parseAddCartItemBody,
  parseProductListQuery,
  parseUpdateCartItemBody,
  parseWishlistBody,
} from "./shop.validation.ts";

type Handler = (req: AuthenticatedRequest, res: Response, next: NextFunction) => Promise<void>;
const handle = (action: Handler): Handler => async (req, res, next) => {
  try {
    await action(req, res, next);
  } catch (error) {
    next(error);
  }
};

const requireUserId = (req: AuthenticatedRequest) => {
  if (!req.user) throw new AppError("User not found", 404);
  return req.user.id;
};

const sectionLimit = (value: unknown) => {
  if (value === undefined) return 12;
  const limit = Number(value);
  if (!Number.isInteger(limit) || limit < 1 || limit > 40) {
    throw new AppError("limit must be an integer between 1 and 40", 400);
  }
  return limit;
};

export const categories = handle(async (_req, res) => {
  const data = await getCategories();
  sendSuccess(res, { data: { items: data } });
});

export const category = handle(async (req, res) => {
  const data = await getCategory(req.params.id as string);
  sendSuccess(res, { data: { category: data } });
});

export const products = handle(async (req, res) => {
  const data = await listProducts(parseProductListQuery(req.query as Record<string, unknown>));
  sendSuccess(res, { data });
});

export const featured = handle(async (req, res) => {
  sendSuccess(res, {
    data: { items: await getFeaturedProducts(sectionLimit(req.query.limit)) },
  });
});

export const newArrivals = handle(async (req, res) => {
  sendSuccess(res, {
    data: { items: await getNewArrivals(sectionLimit(req.query.limit)) },
  });
});

export const recommended = handle(async (req, res) => {
  sendSuccess(res, {
    message: "General recommendations: featured and newest in-stock products; not personalized.",
    data: {
      strategy: "general_featured_then_newest_in_stock",
      items: await getRecommendedProducts(sectionLimit(req.query.limit)),
    },
  });
});

export const product = handle(async (req, res) => {
  const data = await getProduct(req.params.id as string);
  sendSuccess(res, { data: { product: data } });
});

export const cart = handle(async (req, res) => {
  sendSuccess(res, { data: await getCartForUser(requireUserId(req)) });
});

export const cartAdd = handle(async (req, res) => {
  const { productId, variantId, quantity } = parseAddCartItemBody(req.body);
  const item = await addCartItem(requireUserId(req), productId, variantId, quantity);
  sendSuccess(res, { statusCode: 201, message: "Cart item added", data: { item } });
});

export const cartUpdate = handle(async (req, res) => {
  const quantity = parseUpdateCartItemBody(req.body);
  const item = await updateCartItem(requireUserId(req), req.params.itemId as string, quantity);
  sendSuccess(res, { data: { item } });
});

export const cartRemove = handle(async (req, res) => {
  await removeCartItem(requireUserId(req), req.params.itemId as string);
  sendSuccess(res, { message: "Cart item removed", data: {} });
});

export const cartClear = handle(async (req, res) => {
  await clearCart(requireUserId(req));
  sendSuccess(res, { message: "Cart cleared", data: {} });
});

export const wishlist = handle(async (req, res) => {
  sendSuccess(res, { data: await getWishlistForUser(requireUserId(req)) });
});

export const wishlistAdd = handle(async (req, res) => {
  const productId = parseWishlistBody(req.body);
  const item = await addWishlistItem(requireUserId(req), productId);
  sendSuccess(res, { statusCode: 201, message: "Wishlist item saved", data: { item } });
});

export const wishlistRemove = handle(async (req, res) => {
  await removeWishlistItem(requireUserId(req), req.params.itemId as string);
  sendSuccess(res, { message: "Wishlist item removed", data: {} });
});

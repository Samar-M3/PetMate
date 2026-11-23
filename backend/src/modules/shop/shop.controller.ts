import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import {
  cancelOrder,
  createOrderFromCart,
  getOrderDetail,
  getUserOrders,
} from "./shop.orders.service.ts";
import {
  createAddress,
  deleteAddress,
  getAddresses,
  setDefaultAddress,
  updateAddress,
} from "./shop.addresses.service.ts";
import {
  createOrUpdateProductReview,
  getProductReviews,
} from "./shop.reviews.service.ts";
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

// Orders
export const ordersCreate = handle(async (req, res) => {
  const { deliveryAddressId, paymentMethod, customerNotes } = req.body;
  if (!deliveryAddressId) {
    throw new AppError("deliveryAddressId is required", 400);
  }
  const order = await createOrderFromCart(requireUserId(req), {
    deliveryAddressId,
    paymentMethod,
    customerNotes,
  });
  sendSuccess(res, { statusCode: 201, message: "Order placed successfully", data: { order } });
});

export const ordersList = handle(async (req, res) => {
  const orders = await getUserOrders(requireUserId(req));
  sendSuccess(res, { data: { items: orders } });
});

export const orderGet = handle(async (req, res) => {
  const order = await getOrderDetail(requireUserId(req), req.params.id as string);
  sendSuccess(res, { data: { order } });
});

export const orderCancel = handle(async (req, res) => {
  const order = await cancelOrder(requireUserId(req), req.params.id as string, req.body?.reason);
  sendSuccess(res, { message: "Order cancelled successfully", data: { order } });
});

// Addresses
export const addressesList = handle(async (req, res) => {
  const addresses = await getAddresses(requireUserId(req));
  sendSuccess(res, { data: { items: addresses } });
});

export const addressCreate = handle(async (req, res) => {
  const { fullName, phoneNumber, addressLine1, addressLine2, city, province, postalCode, isDefault } = req.body;
  if (!fullName || !phoneNumber || !addressLine1 || !city || !province) {
    throw new AppError("fullName, phoneNumber, addressLine1, city, and province are required", 400);
  }
  const address = await createAddress(requireUserId(req), {
    fullName,
    phoneNumber,
    addressLine1,
    addressLine2,
    city,
    province,
    postalCode,
    isDefault,
  });
  sendSuccess(res, { statusCode: 201, message: "Delivery address created", data: { address } });
});

export const addressUpdate = handle(async (req, res) => {
  const address = await updateAddress(requireUserId(req), req.params.id as string, req.body);
  sendSuccess(res, { message: "Address updated", data: { address } });
});

export const addressDelete = handle(async (req, res) => {
  await deleteAddress(requireUserId(req), req.params.id as string);
  sendSuccess(res, { message: "Address deleted", data: {} });
});

export const addressSetDefault = handle(async (req, res) => {
  const address = await setDefaultAddress(requireUserId(req), req.params.id as string);
  sendSuccess(res, { message: "Default address set", data: { address } });
});

// Reviews
export const reviewsGet = handle(async (req, res) => {
  const data = await getProductReviews(req.params.id as string);
  sendSuccess(res, { data });
});

export const reviewCreate = handle(async (req, res) => {
  const { rating, title, comment } = req.body;
  const review = await createOrUpdateProductReview(requireUserId(req), req.params.id as string, {
    rating: Number(rating),
    title,
    comment,
  });
  sendSuccess(res, { statusCode: 201, message: "Review submitted successfully", data: { review } });
});


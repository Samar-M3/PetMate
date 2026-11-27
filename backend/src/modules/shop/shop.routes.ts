import { Router } from "express";
import { authenticateFirebase, requireInitializedUser } from "../../middleware/auth.middleware.ts";
import {
  addressesList,
  addressCreate,
  addressUpdate,
  addressDelete,
  addressSetDefault,
  ordersCreate,
  ordersList,
  orderGet,
  orderCancel,
  reviewsGet,
  reviewCreate,
  cart,
  cartAdd,
  cartClear,
  cartRemove,
  cartUpdate,
  categories,
  category,
  featured,
  newArrivals,
  product,
  products,
  recommended,
  wishlist,
  wishlistAdd,
  wishlistRemove,
} from "./shop.controller.ts";

const router = Router();

// Public catalogue routes intentionally have no Firebase middleware.
router.get("/categories", categories);
router.get("/categories/:id", category);
router.get("/products", products);
router.get("/products/featured", featured);
router.get("/products/new-arrivals", newArrivals);
router.get("/products/recommended", recommended);
router.get("/products/:id", product);

// Customer routes authenticate with Firebase and derive ownership from req.user.
router.get("/cart", authenticateFirebase, requireInitializedUser, cart);
router.post("/cart/items", authenticateFirebase, requireInitializedUser, cartAdd);
router.patch("/cart/items/:itemId", authenticateFirebase, requireInitializedUser, cartUpdate);
router.delete("/cart/items/:itemId", authenticateFirebase, requireInitializedUser, cartRemove);
router.delete("/cart", authenticateFirebase, requireInitializedUser, cartClear);
router.get("/wishlist", authenticateFirebase, requireInitializedUser, wishlist);
router.post("/wishlist/items", authenticateFirebase, requireInitializedUser, wishlistAdd);
router.delete("/wishlist/items/:itemId", authenticateFirebase, requireInitializedUser, wishlistRemove);

// Delivery Addresses
router.get("/addresses", authenticateFirebase, requireInitializedUser, addressesList);
router.post("/addresses", authenticateFirebase, requireInitializedUser, addressCreate);
router.put("/addresses/:id", authenticateFirebase, requireInitializedUser, addressUpdate);
router.delete("/addresses/:id", authenticateFirebase, requireInitializedUser, addressDelete);
router.patch("/addresses/:id/default", authenticateFirebase, requireInitializedUser, addressSetDefault);

// Orders
router.get("/orders", authenticateFirebase, requireInitializedUser, ordersList);
router.post("/orders", authenticateFirebase, requireInitializedUser, ordersCreate);
router.get("/orders/:id", authenticateFirebase, requireInitializedUser, orderGet);
router.patch("/orders/:id/cancel", authenticateFirebase, requireInitializedUser, orderCancel);

// Reviews (reading reviews is public; writing requires auth)
router.get("/products/:id/reviews", reviewsGet);
router.post("/products/:id/reviews", authenticateFirebase, requireInitializedUser, reviewCreate);

export default router;

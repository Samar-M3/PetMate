import { Prisma } from "../../generated/prisma/client.ts";
import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";

const cartInclude = {
  items: {
    include: {
      product: { include: { images: { orderBy: { displayOrder: "asc" as const } }, store: true } },
      variant: true,
    },
    orderBy: { createdAt: "asc" as const },
  },
};

const withDiscount = <T extends { basePrice: Prisma.Decimal; discountedPrice: Prisma.Decimal | null }>(product: T) => ({
  ...product,
  discountPercentage: product.discountedPrice
    ? Math.round((1 - Number(product.discountedPrice) / Number(product.basePrice)) * 100)
    : null,
});

export const getCartForUser = async (userId: string) => {
  const cart = await prisma.cart.findUnique({ where: { userId }, include: cartInclude });
  const items = cart?.items.map((item) => {
    const active = item.product.status === "ACTIVE" && item.product.store.status === "APPROVED";
    const stock = item.variant ? item.variant.availableStock : item.product.availableStock;
    const available = active && stock >= item.quantity && (!item.variant || item.variant.isAvailable);
    const unitPrice = item.variant?.priceOverride ?? item.product.discountedPrice ?? item.product.basePrice;
    const reason = !active
      ? "no_longer_available"
      : item.variant && !item.variant.isAvailable
        ? "variant_unavailable"
        : stock <= 0
          ? "out_of_stock"
          : stock < item.quantity
            ? "insufficient_stock"
            : null;
    return { ...item, unitPrice, lineSubtotal: unitPrice.mul(item.quantity), availableStock: stock, available, availabilityReason: reason };
  }) ?? [];
  return {
    id: cart?.id ?? null,
    items,
    totalItems: items.length,
    totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
    subtotal: items.reduce((sum, item) => item.available ? sum.add(item.lineSubtotal) : sum, new Prisma.Decimal(0)),
  };
};

export const addCartItem = async (userId: string, productId: string, variantId: string | undefined, quantity: number) =>
  prisma.$transaction(async (tx) => {
    const product = await tx.product.findUnique({ where: { id: productId }, include: { store: true, variants: true } });
    if (!product || product.status !== "ACTIVE" || product.store.status !== "APPROVED") {
      throw new AppError("Product is unavailable", 404);
    }
    let selected: (typeof product.variants)[number] | null = null;
    let stock: number;
    if (product.variants.length) {
      selected = product.variants.find((item) => item.id === variantId) ?? null;
      if (!selected) throw new AppError("A valid variant is required for this product", 400);
      if (!selected.isAvailable) throw new AppError("This variant is unavailable", 409);
      stock = selected.availableStock;
    } else {
      if (variantId) throw new AppError("This product does not have variants", 400);
      stock = product.availableStock;
    }
    const cart = await tx.cart.upsert({ where: { userId }, create: { userId }, update: {} });
    const existing = await tx.cartItem.findFirst({
      where: { cartId: cart.id, productId, variantId: selected?.id ?? null },
    });
    const nextQuantity = (existing?.quantity ?? 0) + quantity;
    if (stock < nextQuantity) throw new AppError("Requested quantity exceeds available stock", 422);
    if (existing) {
      return tx.cartItem.update({ where: { id: existing.id }, data: { quantity: nextQuantity } });
    }
    return tx.cartItem.create({ data: { cartId: cart.id, productId, variantId: selected?.id ?? null, quantity } });
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

export const updateCartItem = async (userId: string, itemId: string, quantity: number) =>
  prisma.$transaction(async (tx) => {
    const item = await tx.cartItem.findFirst({
      where: { id: itemId, cart: { userId } },
      include: { product: { include: { store: true } }, variant: true },
    });
    if (!item) throw new AppError("Cart item not found", 404);
    if (item.product.status !== "ACTIVE" || item.product.store.status !== "APPROVED") {
      throw new AppError("Product is unavailable", 409);
    }
    if (item.variant && !item.variant.isAvailable) throw new AppError("Variant is unavailable", 409);
    const stock = item.variant?.availableStock ?? item.product.availableStock;
    if (quantity > stock) throw new AppError("Requested quantity exceeds available stock", 422);
    return tx.cartItem.update({ where: { id: item.id }, data: { quantity } });
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

export const removeCartItem = async (userId: string, itemId: string) => {
  const item = await prisma.cartItem.findFirst({ where: { id: itemId, cart: { userId } }, select: { id: true } });
  if (!item) throw new AppError("Cart item not found", 404);
  await prisma.cartItem.delete({ where: { id: item.id } });
};

export const clearCart = async (userId: string) => {
  await prisma.cartItem.deleteMany({ where: { cart: { userId } } });
};

export const getWishlistForUser = async (userId: string) => {
  const wishlist = await prisma.wishlist.findUnique({
    where: { userId },
    include: {
      items: {
        include: { product: { include: { images: { orderBy: { displayOrder: "asc" as const } }, variants: true, category: true, store: true } } },
        orderBy: { createdAt: "desc" },
      },
    },
  });
  return {
    id: wishlist?.id ?? null,
    items: wishlist?.items.map(({ product, ...item }) => {
      const active = product.status === "ACTIVE" && product.store.status === "APPROVED";
      const inStock = product.variants.length > 0
        ? product.variants.some((variant) => variant.isAvailable && variant.availableStock > 0)
        : product.availableStock > 0;
      return {
        ...item,
        product: withDiscount(product),
        available: active && inStock,
        availabilityReason: !active ? "no_longer_available" : !inStock ? "out_of_stock" : null,
      };
    }) ?? [],
  };
};

export const addWishlistItem = async (userId: string, productId: string) => {
  if (!(await prisma.product.findUnique({ where: { id: productId }, select: { id: true } }))) {
    throw new AppError("Product not found", 404);
  }
  return prisma.$transaction(async (tx) => {
    const wishlist = await tx.wishlist.upsert({ where: { userId }, create: { userId }, update: {} });
    return tx.wishlistItem.upsert({
      where: { wishlistId_productId: { wishlistId: wishlist.id, productId } },
      create: { wishlistId: wishlist.id, productId },
      update: {},
    });
  });
};

export const removeWishlistItem = async (userId: string, itemId: string) => {
  const item = await prisma.wishlistItem.findFirst({ where: { id: itemId, wishlist: { userId } }, select: { id: true } });
  if (!item) throw new AppError("Wishlist item not found", 404);
  await prisma.wishlistItem.delete({ where: { id: item.id } });
};

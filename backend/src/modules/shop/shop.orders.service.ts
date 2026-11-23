import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import {
  OrderStatus,
  OrderPaymentMethod,
  PaymentStatus,
} from "../../generated/prisma/client.ts";

export interface CreateOrderInput {
  deliveryAddressId: string;
  paymentMethod: OrderPaymentMethod;
  customerNotes?: string;
}

export const createOrderFromCart = async (
  userId: string,
  input: CreateOrderInput
) => {
  // 1. Verify address exists and belongs to user
  const address = await prisma.deliveryAddress.findFirst({
    where: { id: input.deliveryAddressId, userId },
  });
  if (!address) {
    throw new AppError("Delivery address not found or does not belong to you", 404);
  }

  // 2. Fetch cart with items, product, and variant details
  const cart = await prisma.cart.findUnique({
    where: { userId },
    include: {
      items: {
        include: {
          product: {
            include: {
              images: { take: 1, orderBy: { displayOrder: "asc" } },
            },
          },
          variant: true,
        },
      },
    },
  });

  if (!cart || cart.items.length === 0) {
    throw new AppError("Your shopping cart is empty", 400);
  }

  // 3. Process inside a database transaction to ensure stock consistency
  const order = await prisma.$transaction(async (tx) => {
    let subtotal = 0;
    const orderItemsData: {
      productId: string;
      variantId?: string | null;
      quantity: number;
      unitPrice: number;
      totalPrice: number;
    }[] = [];

    for (const item of cart.items) {
      const prod = item.product;
      const variant = item.variant;

      // Determine price
      const unitPrice = variant?.priceOverride
        ? Number(variant.priceOverride)
        : prod.discountedPrice
        ? Number(prod.discountedPrice)
        : Number(prod.basePrice);

      const totalPrice = unitPrice * item.quantity;
      subtotal += totalPrice;

      // Check stock
      if (variant) {
        if (variant.availableStock < item.quantity) {
          throw new AppError(
            `Insufficient stock for variant '${variant.optionKey}' of '${prod.name}'. Available: ${variant.availableStock}`,
            400
          );
        }
        // Decrement variant stock
        await tx.productVariant.update({
          where: { id: variant.id },
          data: { availableStock: { decrement: item.quantity } },
        });
      } else {
        if (prod.availableStock < item.quantity) {
          throw new AppError(
            `Insufficient stock for '${prod.name}'. Available: ${prod.availableStock}`,
            400
          );
        }
        // Decrement product stock
        await tx.product.update({
          where: { id: prod.id },
          data: { availableStock: { decrement: item.quantity } },
        });
      }

      orderItemsData.push({
        productId: prod.id,
        variantId: variant?.id ?? null,
        quantity: item.quantity,
        unitPrice,
        totalPrice,
      });
    }

    // Delivery charge rule: Free delivery over NPR 1500, otherwise NPR 100
    const deliveryCharge = subtotal >= 1500 ? 0 : 100;
    const totalAmount = subtotal + deliveryCharge;

    // Generate human-friendly order number
    const timestamp = Date.now().toString().slice(-6);
    const randomHex = Math.random().toString(16).substring(2, 6).toUpperCase();
    const orderNumber = `PM-${timestamp}-${randomHex}`;

    // Create Order
    const newOrder = await tx.order.create({
      data: {
        orderNumber,
        userId,
        deliveryAddressId: address.id,
        status: OrderStatus.CONFIRMED,
        paymentMethod: input.paymentMethod || OrderPaymentMethod.CASH_ON_DELIVERY,
        paymentStatus:
          input.paymentMethod === OrderPaymentMethod.CASH_ON_DELIVERY
            ? PaymentStatus.PENDING
            : PaymentStatus.COMPLETED,
        subtotal,
        deliveryCharge,
        discount: 0,
        totalAmount,
        customerNotes: input.customerNotes,
        items: {
          create: orderItemsData.map((d) => ({
            productId: d.productId,
            variantId: d.variantId,
            quantity: d.quantity,
            unitPrice: d.unitPrice,
            totalPrice: d.totalPrice,
          })),
        },
      },
      include: {
        items: {
          include: {
            product: {
              include: {
                images: { take: 1, orderBy: { displayOrder: "asc" } },
              },
            },
            variant: true,
          },
        },
        deliveryAddress: true,
      },
    });

    // Clear cart items
    await tx.cartItem.deleteMany({
      where: { cartId: cart.id },
    });

    return newOrder;
  });

  return order;
};

export const getUserOrders = async (userId: string) => {
  return prisma.order.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
    include: {
      items: {
        include: {
          product: {
            include: {
              images: { take: 1, orderBy: { displayOrder: "asc" } },
            },
          },
          variant: true,
        },
      },
      deliveryAddress: true,
    },
  });
};

export const getOrderDetail = async (userId: string, orderId: string) => {
  const order = await prisma.order.findFirst({
    where: { id: orderId, userId },
    include: {
      items: {
        include: {
          product: {
            include: {
              images: { orderBy: { displayOrder: "asc" } },
              category: true,
              store: true,
            },
          },
          variant: true,
        },
      },
      deliveryAddress: true,
    },
  });

  if (!order) {
    throw new AppError("Order not found", 404);
  }

  return order;
};

export const cancelOrder = async (
  userId: string,
  orderId: string,
  reason?: string
) => {
  const order = await prisma.order.findFirst({
    where: { id: orderId, userId },
    include: { items: true },
  });

  if (!order) {
    throw new AppError("Order not found", 404);
  }

  if (
    order.status !== OrderStatus.PENDING &&
    order.status !== OrderStatus.CONFIRMED
  ) {
    throw new AppError(
      `Cannot cancel order in status '${order.status}'. Only PENDING or CONFIRMED orders can be cancelled.`,
      400
    );
  }

  // Restore inventory and update status in transaction
  return prisma.$transaction(async (tx) => {
    for (const item of order.items) {
      if (item.variantId) {
        await tx.productVariant.update({
          where: { id: item.variantId },
          data: { availableStock: { increment: item.quantity } },
        });
      } else {
        await tx.product.update({
          where: { id: item.productId },
          data: { availableStock: { increment: item.quantity } },
        });
      }
    }

    return tx.order.update({
      where: { id: orderId },
      data: {
        status: OrderStatus.CANCELLED,
        cancelledReason: reason || "Cancelled by customer",
      },
      include: {
        items: {
          include: {
            product: true,
          },
        },
        deliveryAddress: true,
      },
    });
  });
};

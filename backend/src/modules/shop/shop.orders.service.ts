import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import {
  OrderStatus,
  OrderPaymentMethod,
  PaymentStatus,
} from "../../generated/prisma/client.ts";

export interface CreateOrderInput {
  deliveryAddressId?: string;
  fullName?: string;
  phoneNumber?: string;
  deliveryAddress?: string;
  landmark?: string;
  deliveryInstructions?: string;
  idempotencyKey?: string;
  paymentMethod?: string;
  customerNotes?: string;
}

export const createOrderFromCart = async (
  userId: string,
  input: CreateOrderInput
) => {
  // 1. Idempotency check: if idempotencyKey provided, check if order was already created
  if (input.idempotencyKey) {
    const existingOrder = await prisma.order.findFirst({
      where: { idempotencyKey: input.idempotencyKey, userId },
      include: {
        items: {
          include: {
            product: {
              include: {
                images: { take: 1, orderBy: { displayOrder: "asc" } },
                store: true,
              },
            },
            variant: true,
          },
        },
        sellerOrders: {
          include: {
            store: true,
            items: true,
          },
        },
        deliveryAddress: true,
      },
    });

    if (existingOrder) {
      return existingOrder;
    }
  }

  // 2. Resolve delivery address / recipient information
  let address = null;
  if (input.deliveryAddressId) {
    address = await prisma.deliveryAddress.findFirst({
      where: { id: input.deliveryAddressId, userId },
    });
    if (!address) {
      throw new AppError("Delivery address not found or does not belong to you", 404);
    }
  }

  const recipientName = input.fullName || address?.fullName;
  const recipientPhone = input.phoneNumber || address?.phoneNumber;
  const deliveryAddressText =
    input.deliveryAddress ||
    (address
      ? `${address.addressLine1}${address.addressLine2 ? `, ${address.addressLine2}` : ""}, ${address.city}, ${address.province}`
      : undefined);

  if (!recipientName || !recipientPhone || !deliveryAddressText) {
    throw new AppError("Delivery recipient name, phone, and address are required", 400);
  }

  // 3. Fetch cart with items, product, store, and variant details
  const cart = await prisma.cart.findUnique({
    where: { userId },
    include: {
      items: {
        include: {
          product: {
            include: {
              store: true,
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

  // 4. Process inside a database transaction to ensure stock consistency and multi-vendor ordering
  const order = await prisma.$transaction(async (tx) => {
    let subtotal = 0;

    // Check stock and decrement inventory safely
    for (const item of cart.items) {
      const prod = item.product;
      const variant = item.variant;

      const unitPrice = variant?.priceOverride
        ? Number(variant.priceOverride)
        : prod.discountedPrice
        ? Number(prod.discountedPrice)
        : Number(prod.basePrice);

      const totalPrice = unitPrice * item.quantity;
      subtotal += totalPrice;

      if (variant) {
        if (variant.availableStock < item.quantity) {
          throw new AppError(
            `Insufficient stock for variant '${variant.optionKey}' of '${prod.name}'. Available: ${variant.availableStock}`,
            400
          );
        }
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
        await tx.product.update({
          where: { id: prod.id },
          data: { availableStock: { decrement: item.quantity } },
        });
      }
    }

    // Delivery charge rule: Free delivery over NPR 1500, otherwise NPR 100
    const deliveryCharge = subtotal >= 1500 ? 0 : 100;
    const totalAmount = subtotal + deliveryCharge;

    // Generate human-friendly order number
    const timestamp = Date.now().toString().slice(-6);
    const randomHex = Math.random().toString(16).substring(2, 6).toUpperCase();
    const orderNumber = `PM-${timestamp}-${randomHex}`;

    // Validate payment method
    let paymentMethodEnum: OrderPaymentMethod = OrderPaymentMethod.CASH_ON_DELIVERY;
    if (input.paymentMethod && Object.values(OrderPaymentMethod).includes(input.paymentMethod as OrderPaymentMethod)) {
      paymentMethodEnum = input.paymentMethod as OrderPaymentMethod;
    }

    // Create Main Order
    const newOrder = await tx.order.create({
      data: {
        orderNumber,
        userId,
        deliveryAddressId: address?.id ?? null,
        fullName: recipientName,
        phoneNumber: recipientPhone,
        deliveryAddressText,
        landmark: input.landmark,
        deliveryInstructions: input.deliveryInstructions,
        idempotencyKey: input.idempotencyKey,
        status: OrderStatus.PENDING,
        paymentMethod: paymentMethodEnum,
        paymentStatus: PaymentStatus.UNPAID,
        subtotal,
        deliveryCharge,
        discount: 0,
        totalAmount,
        customerNotes: input.customerNotes,
      },
    });

    // Group cart items by store to create multi-vendor SellerOrders
    const storeMap = new Map<string, typeof cart.items>();
    for (const item of cart.items) {
      const storeId = item.product.storeId;
      if (storeId) {
        const existing = storeMap.get(storeId) || [];
        existing.push(item);
        storeMap.set(storeId, existing);
      }
    }

    // Create SellerOrder and OrderItems for each store
    for (const [storeId, storeItems] of storeMap.entries()) {
      let storeSubtotal = 0;
      for (const item of storeItems) {
        const prod = item.product;
        const variant = item.variant;
        const unitPrice = variant?.priceOverride
          ? Number(variant.priceOverride)
          : prod.discountedPrice
          ? Number(prod.discountedPrice)
          : Number(prod.basePrice);
        storeSubtotal += unitPrice * item.quantity;
      }

      const sellerOrder = await tx.sellerOrder.create({
        data: {
          orderId: newOrder.id,
          storeId,
          subtotal: storeSubtotal,
          deliveryCharge: 0,
          orderStatus: OrderStatus.PENDING,
        },
      });

      for (const item of storeItems) {
        const prod = item.product;
        const variant = item.variant;
        const unitPrice = variant?.priceOverride
          ? Number(variant.priceOverride)
          : prod.discountedPrice
          ? Number(prod.discountedPrice)
          : Number(prod.basePrice);
        const totalPrice = unitPrice * item.quantity;

        await tx.orderItem.create({
          data: {
            orderId: newOrder.id,
            sellerOrderId: sellerOrder.id,
            productId: prod.id,
            variantId: variant?.id ?? null,
            productName: prod.name,
            productImage: prod.images[0]?.imageUrl ?? null,
            quantity: item.quantity,
            unitPrice,
            totalPrice,
          },
        });
      }
    }

    // Handle items without a designated storeId if any
    const orphanItems = cart.items.filter((item) => !item.product.storeId);
    for (const item of orphanItems) {
      const prod = item.product;
      const variant = item.variant;
      const unitPrice = variant?.priceOverride
        ? Number(variant.priceOverride)
        : prod.discountedPrice
        ? Number(prod.discountedPrice)
        : Number(prod.basePrice);
      const totalPrice = unitPrice * item.quantity;

      await tx.orderItem.create({
        data: {
          orderId: newOrder.id,
          productId: prod.id,
          variantId: variant?.id ?? null,
          productName: prod.name,
          productImage: prod.images[0]?.imageUrl ?? null,
          quantity: item.quantity,
          unitPrice,
          totalPrice,
        },
      });
    }

    // Record initial status history
    await tx.orderStatusHistory.create({
      data: {
        orderId: newOrder.id,
        toStatus: OrderStatus.PENDING,
        changedByUserId: userId,
      },
    });

    // Clear user cart
    await tx.cartItem.deleteMany({
      where: { cartId: cart.id },
    });

    // Fetch the created order with all relations
    return tx.order.findUnique({
      where: { id: newOrder.id },
      include: {
        items: {
          include: {
            product: {
              include: {
                images: { take: 1, orderBy: { displayOrder: "asc" } },
                store: true,
              },
            },
            variant: true,
          },
        },
        sellerOrders: {
          include: {
            store: true,
            items: true,
          },
        },
        deliveryAddress: true,
      },
    });
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
              store: true,
            },
          },
          variant: true,
        },
      },
      sellerOrders: {
        include: {
          store: true,
          items: true,
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
      sellerOrders: {
        include: {
          store: true,
          items: true,
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

    await tx.sellerOrder.updateMany({
      where: { orderId },
      data: { orderStatus: OrderStatus.CANCELLED },
    });

    await tx.orderStatusHistory.create({
      data: {
        orderId,
        fromStatus: order.status,
        toStatus: OrderStatus.CANCELLED,
        changedByUserId: userId,
      },
    });

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
        sellerOrders: true,
        deliveryAddress: true,
      },
    });
  });
};

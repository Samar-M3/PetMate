import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { OrderStatus } from "../../generated/prisma/client.ts";

export const getSellerOrders = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("Store not found for this seller", 404);
  }

  const sellerOrders = await prisma.sellerOrder.findMany({
    where: { storeId: store.id },
    orderBy: { createdAt: "desc" },
    include: {
      order: {
        select: {
          id: true,
          orderNumber: true,
          fullName: true,
          phoneNumber: true,
          deliveryAddressText: true,
          landmark: true,
          deliveryInstructions: true,
          paymentMethod: true,
          paymentStatus: true,
          createdAt: true,
          user: {
            select: {
              id: true,
              fullName: true,
              email: true,
              phone: true,
            },
          },
        },
      },
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
      statusHistory: {
        orderBy: { createdAt: "desc" },
      },
    },
  });

  return sellerOrders;
};

export const getSellerOrderDetail = async (
  userId: string,
  sellerOrderId: string
) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("Store not found for this seller", 404);
  }

  const sellerOrder = await prisma.sellerOrder.findFirst({
    where: { id: sellerOrderId, storeId: store.id },
    include: {
      order: {
        select: {
          id: true,
          orderNumber: true,
          fullName: true,
          phoneNumber: true,
          deliveryAddressText: true,
          landmark: true,
          deliveryInstructions: true,
          paymentMethod: true,
          paymentStatus: true,
          customerNotes: true,
          createdAt: true,
          user: {
            select: {
              id: true,
              fullName: true,
              email: true,
              phone: true,
            },
          },
        },
      },
      items: {
        include: {
          product: {
            include: {
              images: { orderBy: { displayOrder: "asc" } },
              category: true,
            },
          },
          variant: true,
        },
      },
      statusHistory: {
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!sellerOrder) {
    throw new AppError("Seller order not found", 404);
  }

  return sellerOrder;
};

export const updateSellerOrderStatus = async (
  userId: string,
  sellerOrderId: string,
  newStatusRaw: string
) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("Store not found for this seller", 404);
  }

  const sellerOrder = await prisma.sellerOrder.findFirst({
    where: { id: sellerOrderId, storeId: store.id },
    include: { order: true },
  });

  if (!sellerOrder) {
    throw new AppError("Seller order not found", 404);
  }

  const validStatuses: Record<string, OrderStatus> = {
    PENDING: OrderStatus.PENDING,
    RECEIVED: OrderStatus.RECEIVED,
    CONFIRMED: OrderStatus.CONFIRMED,
    PROCESSING: OrderStatus.PROCESSING,
    SHIPPED: OrderStatus.SHIPPED,
    DELIVERED: OrderStatus.DELIVERED,
    CANCELLED: OrderStatus.CANCELLED,
  };

  const targetStatus = validStatuses[newStatusRaw.toUpperCase()];
  if (!targetStatus) {
    throw new AppError(
      `Invalid order status '${newStatusRaw}'. Allowed values: PENDING, RECEIVED, CONFIRMED, PROCESSING, SHIPPED, DELIVERED, CANCELLED`,
      400
    );
  }

  return prisma.$transaction(async (tx) => {
    const updateData: {
      orderStatus: OrderStatus;
      receivedAt?: Date;
      deliveredAt?: Date;
    } = {
      orderStatus: targetStatus,
    };

    if (targetStatus === OrderStatus.RECEIVED && !sellerOrder.receivedAt) {
      updateData.receivedAt = new Date();
    }
    if (targetStatus === OrderStatus.DELIVERED && !sellerOrder.deliveredAt) {
      updateData.deliveredAt = new Date();
    }

    const updatedSellerOrder = await tx.sellerOrder.update({
      where: { id: sellerOrderId },
      data: updateData,
      include: {
        order: true,
        items: true,
        statusHistory: true,
      },
    });

    // Record status history
    await tx.orderStatusHistory.create({
      data: {
        orderId: sellerOrder.orderId,
        sellerOrderId: sellerOrder.id,
        fromStatus: sellerOrder.orderStatus,
        toStatus: targetStatus,
        changedByUserId: userId,
      },
    });

    // Check sibling seller orders to update parent Order status if appropriate
    const allSellerOrders = await tx.sellerOrder.findMany({
      where: { orderId: sellerOrder.orderId },
    });

    const allDelivered = allSellerOrders.every(
      (so) => so.id === sellerOrderId ? targetStatus === OrderStatus.DELIVERED : so.orderStatus === OrderStatus.DELIVERED
    );

    const anyReceived = allSellerOrders.some(
      (so) => so.id === sellerOrderId ? targetStatus === OrderStatus.RECEIVED : so.orderStatus === OrderStatus.RECEIVED
    );

    if (allDelivered) {
      await tx.order.update({
        where: { id: sellerOrder.orderId },
        data: { status: OrderStatus.DELIVERED },
      });
    } else if (anyReceived && sellerOrder.order.status === OrderStatus.PENDING) {
      await tx.order.update({
        where: { id: sellerOrder.orderId },
        data: { status: OrderStatus.RECEIVED },
      });
    }

    return updatedSellerOrder;
  });
};

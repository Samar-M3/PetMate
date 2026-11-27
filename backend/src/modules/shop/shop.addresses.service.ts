import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export interface CreateAddressInput {
  fullName: string;
  phoneNumber: string;
  addressLine1: string;
  addressLine2?: string;
  city: string;
  province: string;
  postalCode?: string;
  isDefault?: boolean;
}

export const getAddresses = async (userId: string) => {
  return prisma.deliveryAddress.findMany({
    where: { userId },
    orderBy: [{ isDefault: "desc" }, { createdAt: "desc" }],
  });
};

export const createAddress = async (
  userId: string,
  input: CreateAddressInput
) => {
  // If set to default, clear previous default
  if (input.isDefault) {
    await prisma.deliveryAddress.updateMany({
      where: { userId, isDefault: true },
      data: { isDefault: false },
    });
  } else {
    // If this is the user's first address, make it default automatically
    const count = await prisma.deliveryAddress.count({ where: { userId } });
    if (count === 0) {
      input.isDefault = true;
    }
  }

  return prisma.deliveryAddress.create({
    data: {
      userId,
      fullName: input.fullName,
      phoneNumber: input.phoneNumber,
      addressLine1: input.addressLine1,
      addressLine2: input.addressLine2,
      city: input.city,
      province: input.province,
      postalCode: input.postalCode,
      isDefault: input.isDefault ?? false,
    },
  });
};

export const updateAddress = async (
  userId: string,
  addressId: string,
  input: Partial<CreateAddressInput>
) => {
  const existing = await prisma.deliveryAddress.findFirst({
    where: { id: addressId, userId },
  });
  if (!existing) {
    throw new AppError("Address not found", 404);
  }

  if (input.isDefault) {
    await prisma.deliveryAddress.updateMany({
      where: { userId, isDefault: true },
      data: { isDefault: false },
    });
  }

  return prisma.deliveryAddress.update({
    where: { id: addressId },
    data: {
      fullName: input.fullName ?? existing.fullName,
      phoneNumber: input.phoneNumber ?? existing.phoneNumber,
      addressLine1: input.addressLine1 ?? existing.addressLine1,
      addressLine2: input.addressLine2 !== undefined ? input.addressLine2 : existing.addressLine2,
      city: input.city ?? existing.city,
      province: input.province ?? existing.province,
      postalCode: input.postalCode !== undefined ? input.postalCode : existing.postalCode,
      isDefault: input.isDefault ?? existing.isDefault,
    },
  });
};

export const deleteAddress = async (userId: string, addressId: string) => {
  const existing = await prisma.deliveryAddress.findFirst({
    where: { id: addressId, userId },
  });
  if (!existing) {
    throw new AppError("Address not found", 404);
  }

  await prisma.deliveryAddress.delete({ where: { id: addressId } });

  // If deleted was default, promote the newest remaining address to default
  if (existing.isDefault) {
    const next = await prisma.deliveryAddress.findFirst({
      where: { userId },
      orderBy: { createdAt: "desc" },
    });
    if (next) {
      await prisma.deliveryAddress.update({
        where: { id: next.id },
        data: { isDefault: true },
      });
    }
  }

  return { success: true };
};

export const setDefaultAddress = async (userId: string, addressId: string) => {
  const existing = await prisma.deliveryAddress.findFirst({
    where: { id: addressId, userId },
  });
  if (!existing) {
    throw new AppError("Address not found", 404);
  }

  await prisma.deliveryAddress.updateMany({
    where: { userId, isDefault: true },
    data: { isDefault: false },
  });

  return prisma.deliveryAddress.update({
    where: { id: addressId },
    data: { isDefault: true },
  });
};

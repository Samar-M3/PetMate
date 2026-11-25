import prisma from "../../config/db.ts";
import { firebaseAuth } from "../../config/firebase.ts";
import {
  Role,
  StoreStatus,
  ApplicationType,
  ApplicationStatus,
  Prisma,
} from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type {
  RegisterSellerInput,
  CreateProductInput,
} from "./sellers.validation.ts";

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export const registerSeller = async (input: RegisterSellerInput) => {
  // 1. Check if email exists in PostgreSQL
  const existingUserByEmail = await prisma.user.findFirst({
    where: { email: { equals: input.email, mode: "insensitive" } },
  });
  if (existingUserByEmail) {
    throw new AppError("An account with this email already exists", 409);
  }

  // 2. Check if store name or slug exists
  const baseSlug = slugify(input.storeName);
  const existingStore = await prisma.store.findFirst({
    where: {
      OR: [
        { name: { equals: input.storeName, mode: "insensitive" } },
        { slug: baseSlug },
      ],
    },
  });
  if (existingStore) {
    throw new AppError(
      "A store with this name already exists. Please choose a different store name.",
      409
    );
  }

  // 3. Create Firebase Auth user
  let firebaseUser;
  try {
    firebaseUser = await firebaseAuth.createUser({
      email: input.email,
      password: input.password,
      displayName: input.fullName,
    });
  } catch (err: any) {
    if (err.code === "auth/email-already-exists") {
      throw new AppError("An account with this email already exists in authentication system", 409);
    }
    throw new AppError(`Authentication setup failed: ${err.message}`, 400);
  }

  // 4. Generate verification link
  let verificationLink: string | null = null;
  try {
    verificationLink = await firebaseAuth.generateEmailVerificationLink(input.email);
  } catch (err) {
    // Non-fatal if email verification link generation fails in development
    console.warn("[SellersService] Notice: could not generate verification link:", err);
  }

  // 5. Create Database Records in Transaction
  try {
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          firebaseUid: firebaseUser.uid,
          email: input.email,
          phoneNumber: input.phoneNumber,
          role: Role.SELLER,
          isActive: true,
          onboardingCompleted: true,
          profile: {
            create: {
              fullName: input.fullName,
              location: `${input.city}, ${input.province}`,
              area: input.city,
            },
          },
        },
        include: { profile: true },
      });

      const store = await tx.store.create({
        data: {
          userId: user.id,
          name: input.storeName,
          slug: baseSlug,
          description: input.description,
          status: StoreStatus.PENDING,
          businessType: input.businessType || "INDIVIDUAL",
          businessAddress: input.businessAddress,
          city: input.city,
          province: input.province,
          postalCode: input.postalCode,
          registrationDocUrl: input.registrationDocUrl,
          identityDocUrl: input.identityDocUrl,
          submittedAt: new Date(),
        },
      });

      const application = await tx.roleApplication.create({
        data: {
          userId: user.id,
          type: ApplicationType.SELLER,
          status: ApplicationStatus.PENDING,
          notes: `Store: ${input.storeName} (${input.businessType || "INDIVIDUAL"}), ${input.city}, ${input.province}`,
        },
      });

      return { user, store, application };
    });

    return {
      message: "Seller registered successfully. Application is currently pending admin review.",
      user: {
        id: result.user.id,
        email: result.user.email,
        fullName: input.fullName,
        role: result.user.role,
      },
      store: {
        id: result.store.id,
        name: result.store.name,
        slug: result.store.slug,
        status: result.store.status,
        businessType: result.store.businessType,
        businessAddress: result.store.businessAddress,
        city: result.store.city,
        province: result.store.province,
        submittedAt: result.store.submittedAt,
      },
      verificationLink,
    };
  } catch (dbError: any) {
    // Rollback Firebase user if DB transaction fails
    try {
      await firebaseAuth.deleteUser(firebaseUser.uid);
    } catch (_) {}
    throw dbError;
  }
};

export const getSellerStatusByUserId = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
    include: {
      owner: {
        select: {
          id: true,
          email: true,
          phoneNumber: true,
          role: true,
          isActive: true,
          profile: { select: { fullName: true } },
        },
      },
    },
  });

  if (!store) {
    // Check if user has a pending role application
    const application = await prisma.roleApplication.findFirst({
      where: { userId, type: ApplicationType.SELLER },
      orderBy: { createdAt: "desc" },
    });

    return {
      hasStore: false,
      applicationStatus: application?.status || "NOT_APPLIED",
      notes: application?.notes,
      store: null,
    };
  }

  return {
    hasStore: true,
    applicationStatus: store.status,
    sellerName: store.owner.profile?.fullName ?? "Seller",
    email: store.owner.email,
    phoneNumber: store.owner.phoneNumber,
    isActive: store.owner.isActive,
    store: {
      id: store.id,
      name: store.name,
      slug: store.slug,
      status: store.status,
      businessType: store.businessType,
      businessAddress: store.businessAddress,
      city: store.city,
      province: store.province,
      postalCode: store.postalCode,
      description: store.description,
      registrationDocUrl: store.registrationDocUrl,
      identityDocUrl: store.identityDocUrl,
      rejectionReason: store.rejectionReason,
      submittedAt: store.submittedAt,
      reviewedAt: store.reviewedAt,
    },
  };
};

export const resubmitSellerApplication = async (
  userId: string,
  data: Partial<RegisterSellerInput>
) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("No seller store found for this account", 404);
  }

  if (store.status === StoreStatus.APPROVED) {
    throw new AppError("This seller application is already approved", 400);
  }

  const updatedStore = await prisma.$transaction(async (tx) => {
    const s = await tx.store.update({
      where: { userId },
      data: {
        name: data.storeName || store.name,
        slug: data.storeName ? slugify(data.storeName) : store.slug,
        description: data.description !== undefined ? data.description : store.description,
        businessType: data.businessType || store.businessType,
        businessAddress: data.businessAddress || store.businessAddress,
        city: data.city || store.city,
        province: data.province || store.province,
        postalCode: data.postalCode || store.postalCode,
        registrationDocUrl: data.registrationDocUrl !== undefined ? data.registrationDocUrl : store.registrationDocUrl,
        identityDocUrl: data.identityDocUrl !== undefined ? data.identityDocUrl : store.identityDocUrl,
        status: StoreStatus.PENDING,
        rejectionReason: null,
        submittedAt: new Date(),
      },
    });

    // Reset role application
    const app = await tx.roleApplication.findFirst({
      where: { userId, type: ApplicationType.SELLER },
      orderBy: { createdAt: "desc" },
    });

    if (app) {
      await tx.roleApplication.update({
        where: { id: app.id },
        data: {
          status: ApplicationStatus.PENDING,
          notes: `Resubmitted: ${s.name} (${s.businessType}), ${s.city}, ${s.province}`,
          reviewedAt: null,
          reviewedBy: null,
        },
      });
    } else {
      await tx.roleApplication.create({
        data: {
          userId,
          type: ApplicationType.SELLER,
          status: ApplicationStatus.PENDING,
          notes: `Resubmitted: ${s.name} (${s.businessType}), ${s.city}, ${s.province}`,
        },
      });
    }

    return s;
  });

  return updatedStore;
};

export const forgotPassword = async (email: string) => {
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    throw new AppError("Please provide a valid email address", 400);
  }

  try {
    const link = await firebaseAuth.generatePasswordResetLink(email.trim().toLowerCase());
    // In production this would dispatch an email; returning link in response or console for easy dev testing
    console.log(`[SellersService] 🔑 Password reset link generated for ${email}: ${link}`);
  } catch (err: any) {
    // For security, never leak whether the email exists
    console.warn(`[SellersService] Password reset requested for unknown or invalid email: ${email}`);
  }

  return {
    message: "If an account is associated with this email, a password reset link has been sent.",
  };
};

export const getSellerDashboardStats = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
    include: {
      products: {
        select: { id: true, name: true, status: true, availableStock: true, basePrice: true },
      },
    },
  });

  if (!store) {
    throw new AppError("Store not found", 404);
  }

  if (store.status !== StoreStatus.APPROVED) {
    throw new AppError("Seller account is not approved yet", 403);
  }

  return {
    store: {
      id: store.id,
      name: store.name,
      slug: store.slug,
      status: store.status,
      businessType: store.businessType,
      city: store.city,
      province: store.province,
    },
    totalProducts: store.products.length,
    activeProducts: store.products.filter((p) => p.status === "ACTIVE").length,
    outOfStockProducts: store.products.filter((p) => p.status === "OUT_OF_STOCK" || p.availableStock <= 0).length,
    products: store.products.slice(0, 5),
  };
};

export const createSellerProduct = async (
  userId: string,
  input: CreateProductInput
) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("Store not found for this seller", 404);
  }

  if (store.status !== StoreStatus.APPROVED) {
    throw new AppError("Only approved sellers can create product listings", 403);
  }

  // Ensure category exists or fallback to first available
  let categoryId = input.categoryId;
  if (categoryId) {
    const cat = await prisma.category.findUnique({ where: { id: categoryId } });
    if (!cat) {
      categoryId = undefined;
    }
  }

  if (!categoryId) {
    const firstCat = await prisma.category.findFirst({ orderBy: { name: "asc" } });
    if (firstCat) {
      categoryId = firstCat.id;
    } else {
      // Auto-create a default category if database has none
      const defaultCat = await prisma.category.create({
        data: {
          name: "Pet Supplies",
          slug: "pet-supplies",
          description: "General pet supplies and accessories",
        },
      });
      categoryId = defaultCat.id;
    }
  }

  // Generate unique slug
  let baseSlug = slugify(input.name);
  if (!baseSlug) baseSlug = "product";
  let slug = baseSlug;
  let counter = 1;
  while (await prisma.product.findUnique({ where: { slug } })) {
    slug = `${baseSlug}-${counter}`;
    counter++;
  }

  const status = input.status === "ACTIVE" ? "ACTIVE" : "DRAFT";

  // Validate discount vs base price according to DB constraint:
  // CHECK ("discounted_price" IS NULL OR ("discounted_price" > 0 AND "discounted_price" < "base_price"))
  let discountedPriceDecimal: Prisma.Decimal | null = null;
  if (
    input.discountedPrice !== undefined &&
    input.discountedPrice !== null &&
    Number(input.discountedPrice) > 0
  ) {
    const discNum = Number(input.discountedPrice);
    if (discNum >= input.basePrice) {
      throw new AppError(
        `Discounted price (${discNum}) must be strictly less than regular price (${input.basePrice})`,
        400
      );
    }
    discountedPriceDecimal = new Prisma.Decimal(discNum);
  }

  const product = await prisma.product.create({
    data: {
      name: input.name,
      slug,
      sku: input.sku || null,
      brand: input.brand || null,
      description: input.description || null,
      shortDescription: input.shortDescription || null,
      basePrice: new Prisma.Decimal(input.basePrice),
      discountedPrice: discountedPriceDecimal,
      costPrice: input.costPrice ? new Prisma.Decimal(input.costPrice) : null,
      availableStock: input.availableStock || 0,
      lowStockThreshold: input.lowStockThreshold || 5,
      status: status as any,
      isFeatured: input.isFeatured || false,
      categoryId: categoryId!,
      storeId: store.id,
      shippingWeight: input.shippingWeight || null,
      packageDimensions: input.packageDimensions || null,
      specifications: input.specifications || null,
      images: {
        create: (input.imageUrls || []).map((url, idx) => ({
          imageUrl: url,
          cloudinaryPublicId: `prod_${Date.now()}_${idx}`,
          displayOrder: idx,
        })),
      },
    },
    include: {
      images: { orderBy: { displayOrder: "asc" } },
      category: true,
      store: {
        select: {
          id: true,
          name: true,
          slug: true,
          status: true,
        },
      },
    },
  });

  return product;
};

export const getSellerProducts = async (userId: string) => {
  const store = await prisma.store.findUnique({
    where: { userId },
  });

  if (!store) {
    throw new AppError("Store not found", 404);
  }

  const products = await prisma.product.findMany({
    where: { storeId: store.id },
    include: {
      images: { orderBy: { displayOrder: "asc" } },
      category: true,
      _count: { select: { orderItems: true } },
    },
    orderBy: { createdAt: "desc" },
  });

  return products.map((p) => ({
    ...p,
    discountPercentage: p.discountedPrice
      ? Math.round((1 - Number(p.discountedPrice) / Number(p.basePrice)) * 100)
      : null,
  }));
};

export const getSellerProductById = async (userId: string, productId: string) => {
  const store = await prisma.store.findUnique({ where: { userId } });
  if (!store) throw new AppError("Store not found", 404);

  const product = await prisma.product.findFirst({
    where: { id: productId, storeId: store.id },
    include: {
      images: { orderBy: { displayOrder: "asc" } },
      category: true,
    },
  });

  if (!product) throw new AppError("Product not found", 404);
  return product;
};

export const updateSellerProduct = async (
  userId: string,
  productId: string,
  input: Partial<CreateProductInput>
) => {
  const store = await prisma.store.findUnique({ where: { userId } });
  if (!store) throw new AppError("Store not found", 404);

  const existing = await prisma.product.findFirst({
    where: { id: productId, storeId: store.id },
  });
  if (!existing) throw new AppError("Product not found", 404);

  const updateData: any = {};
  if (input.name !== undefined) updateData.name = input.name;
  if (input.sku !== undefined) updateData.sku = input.sku || null;
  if (input.brand !== undefined) updateData.brand = input.brand || null;
  if (input.description !== undefined) updateData.description = input.description || null;
  if (input.shortDescription !== undefined) updateData.shortDescription = input.shortDescription || null;
  const effectiveBasePrice = input.basePrice !== undefined ? Number(input.basePrice) : Number(existing.basePrice);

  if (input.basePrice !== undefined) updateData.basePrice = new Prisma.Decimal(input.basePrice);
  if (input.discountedPrice !== undefined) {
    if (input.discountedPrice === null || Number(input.discountedPrice) <= 0) {
      updateData.discountedPrice = null;
    } else {
      const discNum = Number(input.discountedPrice);
      if (discNum >= effectiveBasePrice) {
        throw new AppError(
          `Discounted price (${discNum}) must be strictly less than regular price (${effectiveBasePrice})`,
          400
        );
      }
      updateData.discountedPrice = new Prisma.Decimal(discNum);
    }
  } else if (input.basePrice !== undefined && existing.discountedPrice) {
    if (Number(existing.discountedPrice) >= input.basePrice) {
      throw new AppError(
        `Existing discounted price (${existing.discountedPrice}) cannot be greater than or equal to new regular price (${input.basePrice})`,
        400
      );
    }
  }
  if (input.costPrice !== undefined) {
    updateData.costPrice = input.costPrice ? new Prisma.Decimal(input.costPrice) : null;
  }
  if (input.availableStock !== undefined) updateData.availableStock = input.availableStock;
  if (input.lowStockThreshold !== undefined) updateData.lowStockThreshold = input.lowStockThreshold;
  if (input.status !== undefined) updateData.status = input.status;
  if (input.isFeatured !== undefined) updateData.isFeatured = input.isFeatured;
  if (input.categoryId !== undefined) updateData.categoryId = input.categoryId;
  if (input.shippingWeight !== undefined) updateData.shippingWeight = input.shippingWeight;
  if (input.packageDimensions !== undefined) updateData.packageDimensions = input.packageDimensions;
  if (input.specifications !== undefined) updateData.specifications = input.specifications;

  // If new images provided
  if (input.imageUrls && Array.isArray(input.imageUrls)) {
    await prisma.productImage.deleteMany({ where: { productId } });
    await prisma.productImage.createMany({
      data: input.imageUrls.map((url, idx) => ({
        productId,
        imageUrl: url,
        cloudinaryPublicId: `prod_${Date.now()}_${idx}`,
        displayOrder: idx,
      })),
    });
  }

  const updated = await prisma.product.update({
    where: { id: productId },
    data: updateData,
    include: {
      images: { orderBy: { displayOrder: "asc" } },
      category: true,
    },
  });

  return updated;
};

export const deleteSellerProduct = async (userId: string, productId: string) => {
  const store = await prisma.store.findUnique({ where: { userId } });
  if (!store) throw new AppError("Store not found", 404);

  const existing = await prisma.product.findFirst({
    where: { id: productId, storeId: store.id },
    include: { _count: { select: { orderItems: true } } },
  });
  if (!existing) throw new AppError("Product not found", 404);

  if (existing._count.orderItems > 0) {
    // Cannot hard delete if order history exists; archive it
    await prisma.product.update({
      where: { id: productId },
      data: { status: "INACTIVE" as any },
    });
    return { message: "Product has associated orders; marked as INACTIVE." };
  }

  // Delete product images first, then product
  await prisma.productImage.deleteMany({ where: { productId } });
  await prisma.product.delete({ where: { id: productId } });

  return { message: "Product deleted successfully" };
};

export const updateSellerProductStock = async (
  userId: string,
  productId: string,
  stock: number
) => {
  const store = await prisma.store.findUnique({ where: { userId } });
  if (!store) throw new AppError("Store not found", 404);

  const existing = await prisma.product.findFirst({
    where: { id: productId, storeId: store.id },
  });
  if (!existing) throw new AppError("Product not found", 404);

  const newStock = Math.max(0, stock);
  const newStatus = newStock === 0 && existing.status === "ACTIVE"
    ? "OUT_OF_STOCK"
    : existing.status === "OUT_OF_STOCK" && newStock > 0
    ? "ACTIVE"
    : existing.status;

  const updated = await prisma.product.update({
    where: { id: productId },
    data: {
      availableStock: newStock,
      status: newStatus as any,
    },
  });

  return updated;
};

export const toggleSellerProductStatus = async (
  userId: string,
  productId: string,
  targetStatus?: string
) => {
  const store = await prisma.store.findUnique({ where: { userId } });
  if (!store) throw new AppError("Store not found", 404);

  const existing = await prisma.product.findFirst({
    where: { id: productId, storeId: store.id },
  });
  if (!existing) throw new AppError("Product not found", 404);

  const nextStatus = targetStatus || (existing.status === "ACTIVE" ? "DRAFT" : "ACTIVE");

  const updated = await prisma.product.update({
    where: { id: productId },
    data: { status: nextStatus as any },
  });

  return updated;
};

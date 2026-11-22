import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export interface CreateReviewInput {
  rating: number;
  title?: string;
  comment?: string;
}

export const getProductReviews = async (productId: string) => {
  const reviews = await prisma.review.findMany({
    where: { productId },
    orderBy: { createdAt: "desc" },
    include: {
      user: {
        select: {
          id: true,
          profile: {
            select: {
              fullName: true,
              profilePictureUrl: true,
              imageUrl: true,
            },
          },
        },
      },
    },
  });

  const totalReviews = reviews.length;
  const avgRating =
    totalReviews > 0
      ? Number(
          (
            reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
          ).toFixed(1)
        )
      : 5.0;

  return {
    reviews: reviews.map((r) => ({
      id: r.id,
      rating: r.rating,
      title: r.title,
      comment: r.comment,
      images: r.images,
      createdAt: r.createdAt,
      userName: r.user.profile?.fullName ?? "Pet Parent",
      userAvatar: r.user.profile?.profilePictureUrl ?? r.user.profile?.imageUrl ?? null,
    })),
    totalReviews,
    avgRating,
  };
};

export const createOrUpdateProductReview = async (
  userId: string,
  productId: string,
  input: CreateReviewInput
) => {
  if (!input.rating || input.rating < 1 || input.rating > 5) {
    throw new AppError("Rating must be an integer between 1 and 5", 400);
  }

  const product = await prisma.product.findUnique({
    where: { id: productId },
  });
  if (!product) {
    throw new AppError("Product not found", 404);
  }

  return prisma.review.upsert({
    where: {
      userId_productId: { userId, productId },
    },
    create: {
      userId,
      productId,
      rating: input.rating,
      title: input.title,
      comment: input.comment,
    },
    update: {
      rating: input.rating,
      title: input.title,
      comment: input.comment,
    },
    include: {
      user: {
        select: {
          id: true,
          profile: {
            select: {
              fullName: true,
              profilePictureUrl: true,
              imageUrl: true,
            },
          },
        },
      },
    },
  });
};

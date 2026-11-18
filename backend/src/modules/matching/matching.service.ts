import prisma from "../../config/db.ts";
import { SwipeAction, RequestStatus } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export { SwipeAction, RequestStatus };

export function calculateAgeString(dob?: Date | null): string {
  if (!dob) return "Unknown age";
  const now = new Date();
  let years = now.getFullYear() - dob.getFullYear();
  let months = now.getMonth() - dob.getMonth();
  if (now.getDate() < dob.getDate()) {
    months--;
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  if (years <= 0 && months <= 0) {
    return "Less than a month";
  }
  if (years <= 0) {
    return `${months} ${months === 1 ? "month" : "months"} old`;
  }
  if (months === 0) {
    return `${years} ${years === 1 ? "year" : "years"} old`;
  }
  return `${years} yr ${months} mo old`;
}

export interface DiscoverFeedParams {
  userId: string;
  petId: string;
  cursor?: string;
  limit?: number;
}

export const getDiscoverFeed = async ({
  userId,
  petId,
  cursor,
  limit = 10,
}: DiscoverFeedParams) => {
  // 1. Verify caller owns petId
  const swiperPet = await prisma.pet.findFirst({
    where: { id: petId, userId },
  });

  if (!swiperPet) {
    throw new AppError("Swiper pet not found or unauthorized", 404);
  }

  // 2. Collect IDs of pets this petId has already swiped on (LIKE or PASS)
  const existingSwipes = await prisma.petSwipe.findMany({
    where: { swiperPetId: petId },
    select: { targetPetId: true },
  });
  const swipedTargetPetIds = existingSwipes.map((s) => s.targetPetId);

  // 3. // PART 2 HOOK: also exclude users who have a PENDING request with this user in either direction
  const pendingRequests = await prisma.connectionRequest.findMany({
    where: {
      status: RequestStatus.PENDING,
      OR: [
        { senderUserId: userId },
        { receiverUserId: userId },
      ],
    },
    select: { senderUserId: true, receiverUserId: true },
  });

  const pendingUserIds = new Set<string>();
  for (const req of pendingRequests) {
    if (req.senderUserId !== userId) pendingUserIds.add(req.senderUserId);
    if (req.receiverUserId !== userId) pendingUserIds.add(req.receiverUserId);
  }
  const excludedPendingUserIds = Array.from(pendingUserIds);

  // // PART 3 HOOK: also exclude users with a match

  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  const candidatePets = await prisma.pet.findMany({
    where: {
      userId: {
        not: userId,
        ...(excludedPendingUserIds.length > 0
          ? { notIn: excludedPendingUserIds }
          : {}),
      },
      id: swipedTargetPetIds.length > 0 ? { notIn: swipedTargetPetIds } : undefined,
      user: { isActive: true },
      name: { not: "" },
      OR: [
        { imageUrl: { not: null } },
        { profilePictureUrl: { not: null } },
      ],
    },
    take: effectiveLimit + 1,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      name: true,
      animalType: true,
      breed: true,
      gender: true,
      dateOfBirth: true,
      color: true,
      personality: true,
      vaccinationStatus: true,
      allergies: true,
      description: true,
      imageUrl: true,
      profilePictureUrl: true,
      createdAt: true,
      user: {
        select: {
          id: true,
          profile: {
            select: {
              fullName: true,
              username: true,
              location: true,
              area: true,
              imageUrl: true,
              profilePictureUrl: true,
            },
          },
        },
      },
    },
  });

  let nextCursor: string | null = null;
  if (candidatePets.length > effectiveLimit) {
    const extraItem = candidatePets.pop()!;
    nextCursor = extraItem.id;
  }

  const items = candidatePets.map((p) => {
    const profile = p.user.profile;
    const effectiveImageUrl = p.imageUrl || p.profilePictureUrl || "";
    const ownerAvatarUrl = profile?.imageUrl || profile?.profilePictureUrl || null;
    const ownerName = profile?.fullName || profile?.username || "Pet Parent";
    const ownerUsername = profile?.username || profile?.fullName || "Pet Parent";
    const ownerLocation =
      [profile?.area, profile?.location].filter(Boolean).join(", ") ||
      "Kathmandu, Nepal";

    return {
      id: p.id,
      name: p.name,
      petName: p.name,
      petAge: calculateAgeString(p.dateOfBirth),
      dateOfBirth: p.dateOfBirth,
      animalType: p.animalType || "Dog",
      breed: p.breed || "",
      petBreed: p.breed || "",
      gender: p.gender || "Unknown",
      petGender: p.gender || "Unknown",
      color: p.color,
      personality: p.personality,
      vaccinationStatus: p.vaccinationStatus,
      allergies: p.allergies,
      bio: p.description || "",
      petBio: p.description || "",
      imageUrl: effectiveImageUrl,
      petImageUrl: effectiveImageUrl,
      ownerId: p.user.id,
      ownerName,
      ownerUsername,
      ownerLocation,
      ownerAvatarUrl,
      createdAt: p.createdAt,
    };
  });

  return {
    pets: items,
    nextCursor,
    hasMore: Boolean(nextCursor),
  };
};

export interface RecordSwipeParams {
  userId: string;
  petId: string;
  targetPetId: string;
  action: SwipeAction;
}

export const recordSwipe = async ({
  userId,
  petId,
  targetPetId,
  action,
}: RecordSwipeParams) => {
  if (petId === targetPetId) {
    throw new AppError("A pet cannot swipe on itself", 400);
  }

  if (!Object.values(SwipeAction).includes(action)) {
    throw new AppError(`Invalid swipe action: ${action}. Must be LIKE or PASS`, 400);
  }

  // Multi-step write wrapped in prisma.$transaction
  return await prisma.$transaction(async (tx) => {
    // 1. Verify caller owns swiper pet
    const swiperPet = await tx.pet.findFirst({
      where: { id: petId, userId },
    });
    if (!swiperPet) {
      throw new AppError("Swiper pet not found or unauthorized", 404);
    }

    // 2. Verify target pet exists
    const targetPet = await tx.pet.findUnique({
      where: { id: targetPetId },
      include: { user: true },
    });
    if (!targetPet) {
      throw new AppError("Target pet not found", 404);
    }

    // 3. Verify target owner is not self
    if (targetPet.userId === userId) {
      throw new AppError("Cannot swipe on your own pet", 400);
    }

    // 4. Idempotency: Check if swipe already exists
    const existingSwipe = await tx.petSwipe.findUnique({
      where: {
        swiperPetId_targetPetId: {
          swiperPetId: petId,
          targetPetId,
        },
      },
    });

    if (existingSwipe) {
      return {
        status: "recorded",
        alreadyExisted: true,
        swipeId: existingSwipe.id,
      };
    }

    // 5. Create the swipe record
    let newSwipe;
    try {
      newSwipe = await tx.petSwipe.create({
        data: {
          swiperUserId: userId,
          swiperPetId: petId,
          targetPetId,
          targetUserId: targetPet.userId,
          action,
        },
      });
    } catch (err: any) {
      // Catch P2002 race condition on concurrent swipe
      if (err.code === "P2002") {
        const found = await tx.petSwipe.findUnique({
          where: {
            swiperPetId_targetPetId: {
              swiperPetId: petId,
              targetPetId,
            },
          },
        });
        return {
          status: "recorded",
          alreadyExisted: true,
          swipeId: found?.id,
        };
      }
      throw err;
    }

    // 6. On LIKE, create PENDING connection request inside the same transaction
    if (action === SwipeAction.LIKE) {
      // // PART 3 HOOK: mutual like -> auto-accept + match
      try {
        await tx.connectionRequest.create({
          data: {
            senderUserId: userId,
            senderPetId: petId,
            receiverUserId: targetPet.userId,
            receiverPetId: targetPetId,
            status: RequestStatus.PENDING,
          },
        });
      } catch (reqErr: any) {
        // Repeat call or race must not fail if request already exists (catch P2002)
        if (reqErr.code !== "P2002") {
          throw reqErr;
        }
      }
    }

    return {
      status: "recorded",
      alreadyExisted: false,
      swipeId: newSwipe.id,
    };
  });
};

export interface IncomingRequestsParams {
  userId: string;
  cursor?: string;
  limit?: number;
}

export const getIncomingRequests = async ({
  userId,
  cursor,
  limit = 20,
}: IncomingRequestsParams) => {
  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  const requests = await prisma.connectionRequest.findMany({
    where: {
      receiverUserId: userId,
      status: RequestStatus.PENDING,
    },
    take: effectiveLimit + 1,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      status: true,
      createdAt: true,
      senderPet: {
        select: {
          id: true,
          name: true,
          imageUrl: true,
          profilePictureUrl: true,
          breed: true,
          gender: true,
        },
      },
      senderUser: {
        select: {
          id: true,
          profile: {
            select: {
              fullName: true,
              username: true,
              imageUrl: true,
              profilePictureUrl: true,
            },
          },
        },
      },
      receiverPet: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  let nextCursor: string | null = null;
  if (requests.length > effectiveLimit) {
    const extra = requests.pop()!;
    nextCursor = extra.id;
  }

  const items = requests.map((r) => {
    const senderProfile = r.senderUser.profile;
    const senderUsername =
      senderProfile?.username || senderProfile?.fullName || "Pet Parent";
    const senderPetPhoto =
      r.senderPet.imageUrl || r.senderPet.profilePictureUrl || "";

    return {
      id: r.id,
      senderUserId: r.senderUser.id,
      senderUsername,
      senderPetId: r.senderPet.id,
      senderPetName: r.senderPet.name,
      senderPetImageUrl: senderPetPhoto,
      senderPetBreed: r.senderPet.breed || "",
      receiverPetId: r.receiverPet.id,
      receiverPetName: r.receiverPet.name,
      status: r.status,
      createdAt: r.createdAt,
    };
  });

  const pendingCount = await prisma.connectionRequest.count({
    where: {
      receiverUserId: userId,
      status: RequestStatus.PENDING,
    },
  });

  return {
    requests: items,
    nextCursor,
    hasMore: Boolean(nextCursor),
    pendingCount,
  };
};

export const acceptConnectionRequest = async (
  userId: string,
  requestId: string
) => {
  // Check existence and verify caller is the receiver
  const existing = await prisma.connectionRequest.findUnique({
    where: { id: requestId },
  });

  if (!existing) {
    throw new AppError("Connection request not found", 404);
  }

  if (existing.receiverUserId !== userId) {
    throw new AppError(
      "Access forbidden: you are not the receiver of this request",
      403
    );
  }

  if (existing.status !== RequestStatus.PENDING) {
    throw new AppError(
      `Request has already been ${existing.status.toLowerCase()}`,
      409
    );
  }

  // Atomic updateMany ensures double tap or race cannot succeed twice
  return await prisma.$transaction(async (tx) => {
    const updateResult = await tx.connectionRequest.updateMany({
      where: {
        id: requestId,
        receiverUserId: userId,
        status: RequestStatus.PENDING,
      },
      data: {
        status: RequestStatus.ACCEPTED,
        respondedAt: new Date(),
      },
    });

    if (updateResult.count !== 1) {
      throw new AppError("Request has already been responded to", 409);
    }

    // // PART 3 HOOK: create Match in the same transaction

    return {
      requestId,
      status: "ACCEPTED",
      matchId: null,
    };
  });
};

export const rejectConnectionRequest = async (
  userId: string,
  requestId: string
) => {
  const existing = await prisma.connectionRequest.findUnique({
    where: { id: requestId },
  });

  if (!existing) {
    throw new AppError("Connection request not found", 404);
  }

  if (existing.receiverUserId !== userId) {
    throw new AppError(
      "Access forbidden: you are not the receiver of this request",
      403
    );
  }

  if (existing.status !== RequestStatus.PENDING) {
    throw new AppError(
      `Request has already been ${existing.status.toLowerCase()}`,
      409
    );
  }

  const updateResult = await prisma.connectionRequest.updateMany({
    where: {
      id: requestId,
      receiverUserId: userId,
      status: RequestStatus.PENDING,
    },
    data: {
      status: RequestStatus.REJECTED,
      respondedAt: new Date(),
    },
  });

  if (updateResult.count !== 1) {
    throw new AppError("Request has already been responded to", 409);
  }

  return {
    requestId,
    status: "REJECTED",
  };
};

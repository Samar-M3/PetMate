import prisma from "../../config/db.ts";
import {
  SwipeAction,
  RequestStatus,
  MatchStatus,
} from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import matchingConfig from "../../config/matching.config.ts";
import { expireOldRequests } from "./matching.expiry.ts";
import { expireSlotsAndDowngrade } from "../slots/slots.expiry.ts";
import { ensureConversation, endConversation } from "../../services/firestore.service.ts";

export { SwipeAction, RequestStatus, MatchStatus };

export function calculateAgeInMonths(dob?: Date | null): number {
  if (!dob) return 0;
  const now = new Date();
  let months = (now.getFullYear() - dob.getFullYear()) * 12 + (now.getMonth() - dob.getMonth());
  if (now.getDate() < dob.getDate()) {
    months--;
  }
  return Math.max(0, months);
}

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

export interface DeckFeedParams {
  userId: string;
  actingPetId: string;
  cursor?: string;
  limit?: number;
  species?: string;
  breed?: string;
  ageMin?: number;
  ageMax?: number;
  area?: string;
}

export const getDeckFeed = async ({
  userId,
  actingPetId,
  cursor,
  limit = 20,
  species,
  breed,
  ageMin,
  ageMax,
  area,
}: DeckFeedParams) => {
  // 1. Run lazy expiration of pending requests and slots
  await expireOldRequests();
  await expireSlotsAndDowngrade(userId);

  // 2. Validate acting pet belongs to caller and is active
  const actingPet = await prisma.pet.findFirst({
    where: { id: actingPetId, userId },
    include: { user: true },
  });

  if (!actingPet) {
    throw new AppError("Acting pet not found or unauthorized", 404);
  }

  if (!actingPet.user.isActive) {
    throw new AppError("Your account is suspended or inactive", 403);
  }

  if (!actingPet.isActive) {
    throw new AppError("Acting pet is inactive. Only active pets can view the deck or swipe.", 400);
  }

  // 3. Exclusions:
  // 3a. LIKE swipes by acting pet (never shown again)
  const likeSwipes = await prisma.petSwipe.findMany({
    where: {
      swiperPetId: actingPetId,
      action: SwipeAction.LIKE,
    },
    select: { targetPetId: true },
  });
  const likedPetIds = likeSwipes.map((s) => s.targetPetId);

  // 3b. PASS swipes newer than PASS_COOLDOWN_DAYS
  const cooldownThreshold = new Date(
    Date.now() - matchingConfig.PASS_COOLDOWN_DAYS * 24 * 60 * 60 * 1000
  );
  const activePassSwipes = await prisma.petSwipe.findMany({
    where: {
      swiperPetId: actingPetId,
      action: SwipeAction.PASS,
      createdAt: { gte: cooldownThreshold },
    },
    select: { targetPetId: true },
  });
  const passedRecentPetIds = activePassSwipes.map((s) => s.targetPetId);

  // 3c. MatchRequest between the pair:
  // - Requests sent BY acting pet: excluded (acting pet already liked or acted on them)
  // - Requests ACCEPTED, DECLINED, or REJECTED: excluded for both pets
  // - Note: PENDING requests received by acting pet are NOT excluded, so the acting pet can also discover and like back
  const relatedRequests = await prisma.connectionRequest.findMany({
    where: {
      OR: [
        { senderPetId: actingPetId },
        {
          receiverPetId: actingPetId,
          status: {
            in: [
              RequestStatus.ACCEPTED,
              RequestStatus.DECLINED,
              RequestStatus.REJECTED,
            ],
          },
        },
      ],
    },
    select: { senderPetId: true, receiverPetId: true },
  });
  const requestExcludedPetIds = new Set<string>();
  for (const req of relatedRequests) {
    if (req.senderPetId !== actingPetId) requestExcludedPetIds.add(req.senderPetId);
    if (req.receiverPetId !== actingPetId) requestExcludedPetIds.add(req.receiverPetId);
  }

  // 3d. Match between the pair in ANY status (ACTIVE or ENDED)
  const existingMatches = await prisma.match.findMany({
    where: {
      OR: [
        { petAId: actingPetId },
        { petBId: actingPetId },
      ],
    },
    select: { petAId: true, petBId: true },
  });
  const matchedPetIds = new Set<string>();
  for (const m of existingMatches) {
    if (m.petAId !== actingPetId) matchedPetIds.add(m.petAId);
    if (m.petBId !== actingPetId) matchedPetIds.add(m.petBId);
  }

  // Combine all excluded pet IDs
  const allExcludedPetIds = Array.from(
    new Set([
      actingPetId,
      ...likedPetIds,
      ...passedRecentPetIds,
      ...Array.from(requestExcludedPetIds),
      ...Array.from(matchedPetIds),
    ])
  );

  // 4. Age filtering
  const now = new Date();
  let dobCondition: any = undefined;
  if (ageMin !== undefined || ageMax !== undefined) {
    dobCondition = {};
    if (ageMax !== undefined) {
      // e.g. age <= 5 means born after (now - 5 years)
      const minDob = new Date(now.getFullYear() - ageMax - 1, now.getMonth(), now.getDate());
      dobCondition.gte = minDob;
    }
    if (ageMin !== undefined) {
      // e.g. age >= 2 means born before (now - 2 years)
      const maxDob = new Date(now.getFullYear() - ageMin, now.getMonth(), now.getDate());
      dobCondition.lte = maxDob;
    }
  }

  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  // 5. Query Candidate Pets (Shows ALL pets regardless of species or gender)
  const candidatePets = await prisma.pet.findMany({
    where: {
      // Not belonging to same owner
      userId: { not: userId },
      // Candidate owner is active and not suspended
      user: {
        isActive: true,
        ...(area
          ? {
              profile: {
                area: { contains: area, mode: "insensitive" },
              },
            }
          : {}),
      },
      // Exclude all ineligible pets
      id: { notIn: allExcludedPetIds },
      // Optional Species filter (only if explicitly provided by caller)
      ...(species ? { animalType: { contains: species, mode: "insensitive" } } : {}),
      // Optional Breed filter
      ...(breed ? { breed: { contains: breed, mode: "insensitive" } } : {}),
      // Optional Age filter
      ...(dobCondition ? { dateOfBirth: dobCondition } : {}),
      // Candidate pet must be active and complete (has a valid name and image)
      isActive: true,
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
      images: {
        select: {
          id: true,
          imageUrl: true,
          isMain: true,
        },
      },
      user: {
        select: {
          id: true,
          profile: {
            select: {
              fullName: true,
              profilePictureUrl: true,
              imageUrl: true,
              area: true,
              location: true,
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

  // 7. Format safe public fields ONLY (never return owner contact details or email/phone/UID)
  const items = candidatePets.map((p) => {
    const profile = p.user.profile;
    const effectiveImageUrl = p.imageUrl || p.profilePictureUrl || "";
    const allPhotos: string[] = [];
    if (effectiveImageUrl) allPhotos.push(effectiveImageUrl);
    if (p.images && p.images.length > 0) {
      for (const img of p.images) {
        if (img.imageUrl && !allPhotos.includes(img.imageUrl)) {
          allPhotos.push(img.imageUrl);
        }
      }
    }

    const areaString =
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
      photos: allPhotos,
      area: areaString,
      location: areaString,
      ownerId: p.user.id,
      ownerName: profile?.fullName || "Pet Parent",
      ownerAvatarUrl: profile?.profilePictureUrl || profile?.imageUrl || null,
      ownerLocation: areaString,
      healthBadges: [
        ...(p.vaccinationStatus ? [p.vaccinationStatus] : []),
        ...(p.allergies ? [`Allergies: ${p.allergies}`] : []),
      ],
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
  const result: {
    status: string;
    matched: boolean;
    matchId?: string;
    swipeId: string;
  } = await prisma.$transaction(async (tx) => {
    // 1. Verify caller owns swiper pet and swiper is active
    const swiperPet = await tx.pet.findFirst({
      where: { id: petId, userId },
      include: { user: true },
    });
    if (!swiperPet) {
      throw new AppError("Swiper pet not found or unauthorized", 404);
    }
    if (!swiperPet.user.isActive) {
      throw new AppError("Your account is inactive or suspended", 403);
    }
    if (!swiperPet.isActive) {
      throw new AppError("Swiper pet is inactive. Only active pets can swipe.", 400);
    }

    // 2. Verify target pet exists and target owner is active
    const targetPet = await tx.pet.findUnique({
      where: { id: targetPetId },
      include: { user: true },
    });
    if (!targetPet) {
      throw new AppError("Target pet not found", 404);
    }
    if (!targetPet.user.isActive) {
      throw new AppError("Target pet owner is inactive", 400);
    }
    if (!targetPet.isActive) {
      throw new AppError("Target pet is currently inactive and cannot be swiped on", 400);
    }

    // 3. Verify target owner is not self
    if (targetPet.userId === userId) {
      throw new AppError("Cannot swipe on your own pet", 400);
    }

    // 4. If action is LIKE, check MAX_PENDING_REQUESTS for the caller/owner
    if (action === SwipeAction.LIKE) {
      const activePendingCount = await tx.connectionRequest.count({
        where: {
          senderUserId: userId,
          status: RequestStatus.PENDING,
          OR: [
            { expiresAt: null },
            { expiresAt: { gt: new Date() } },
          ],
        },
      });

      if (activePendingCount >= matchingConfig.MAX_PENDING_REQUESTS) {
        throw new AppError(
          `You have reached the limit of ${matchingConfig.MAX_PENDING_REQUESTS} pending requests. Please wait for responses before liking more pets.`,
          429
        );
      }
    }

    // 5. Upsert swipe (latest wins after cooldown)
    const existingSwipe = await tx.petSwipe.findUnique({
      where: {
        swiperPetId_targetPetId: {
          swiperPetId: petId,
          targetPetId,
        },
      },
    });

    let newSwipe;
    if (existingSwipe) {
      newSwipe = await tx.petSwipe.update({
        where: { id: existingSwipe.id },
        data: {
          action,
          createdAt: new Date(),
        },
      });
    } else {
      newSwipe = await tx.petSwipe.create({
        data: {
          swiperUserId: userId,
          swiperPetId: petId,
          targetPetId,
          targetUserId: targetPet.userId,
          action,
        },
      });
    }

    // 6. Right swipe (LIKE) logic:
    // Check if other pet already has a PENDING request to this pet
    if (action === SwipeAction.LIKE) {
      const oppositeRequest = await tx.connectionRequest.findFirst({
        where: {
          senderPetId: targetPetId,
          receiverPetId: petId,
          status: RequestStatus.PENDING,
          OR: [
            { expiresAt: null },
            { expiresAt: { gt: new Date() } },
          ],
        },
      });

      if (oppositeRequest) {
        // Mutual like -> Accept both / create match immediately
        await tx.connectionRequest.update({
          where: { id: oppositeRequest.id },
          data: {
            status: RequestStatus.ACCEPTED,
            respondedAt: new Date(),
          },
        });

        // Determine canonical petA / petB ordering
        const [petAId, petBId] =
          petId < targetPetId ? [petId, targetPetId] : [targetPetId, petId];

        const match = await tx.match.upsert({
          where: {
            petAId_petBId: { petAId, petBId },
          },
          update: {
            status: MatchStatus.ACTIVE,
            endedAt: null,
            endedBy: null,
          },
          create: {
            petAId,
            petBId,
            status: MatchStatus.ACTIVE,
          },
        });

        return {
          status: "matched",
          matched: true,
          matchId: match.id,
          swipeId: newSwipe.id,
        };
      } else {
        // Create new PENDING request with expiresAt
        const expiresAt = new Date(
          Date.now() + matchingConfig.REQUEST_EXPIRY_DAYS * 24 * 60 * 60 * 1000
        );

        await tx.connectionRequest.upsert({
          where: {
            senderPetId_receiverPetId: {
              senderPetId: petId,
              receiverPetId: targetPetId,
            },
          },
          update: {
            status: RequestStatus.PENDING,
            expiresAt,
            createdAt: new Date(),
            respondedAt: null,
          },
          create: {
            senderUserId: userId,
            senderPetId: petId,
            receiverUserId: targetPet.userId,
            receiverPetId: targetPetId,
            status: RequestStatus.PENDING,
            expiresAt,
          },
        });
      }
    }

    return {
      status: "recorded",
      matched: false,
      swipeId: newSwipe.id,
    };
  });

  // Ensure Firestore conversation if a match was formed
  if (result.matched && result.matchId) {
    try {
      const matchRecord = await prisma.match.findUnique({
        where: { id: result.matchId },
        include: {
          petA: { include: { user: true } },
          petB: { include: { user: true } },
        },
      });
      const uidA = matchRecord?.petA?.user?.firebaseUid;
      const uidB = matchRecord?.petB?.user?.firebaseUid;
      if (uidA && uidB) {
        await ensureConversation(result.matchId, [uidA, uidB]);
      }
    } catch (err) {
      console.error("[MatchingService] Post-swipe conversation creation error:", err);
    }
  }

  return result;
};

export interface UndoSwipeParams {
  userId: string;
  petId: string;
}

export const undoLastPassSwipe = async ({
  userId,
  petId,
}: UndoSwipeParams) => {
  // Undo: allow undoing the last PASS only (not likes), within 10 minutes.
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

  // 1. Verify acting pet belongs to user
  const actingPet = await prisma.pet.findFirst({
    where: { id: petId, userId },
  });
  if (!actingPet) {
    throw new AppError("Acting pet not found or unauthorized", 404);
  }

  // 2. Find latest swipe for acting pet
  const latestSwipe = await prisma.petSwipe.findFirst({
    where: { swiperPetId: petId },
    orderBy: { createdAt: "desc" },
  });

  if (!latestSwipe) {
    throw new AppError("No recent swipe found to undo", 404);
  }

  if (latestSwipe.action !== SwipeAction.PASS) {
    throw new AppError("Only PASS swipes can be undone. LIKE swipes cannot be undone.", 400);
  }

  if (latestSwipe.createdAt < tenMinutesAgo) {
    throw new AppError("Undo window expired. Swipes can only be undone within 10 minutes.", 400);
  }

  // 3. Delete or remove the pass swipe
  await prisma.petSwipe.delete({
    where: { id: latestSwipe.id },
  });

  return {
    success: true,
    message: "Last PASS swipe undone successfully",
    undoneTargetPetId: latestSwipe.targetPetId,
  };
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
  // Run lazy expiration before listing
  await expireOldRequests();

  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  const requests = await prisma.connectionRequest.findMany({
    where: {
      receiverUserId: userId,
      status: RequestStatus.PENDING,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: new Date() } },
      ],
    },
    take: effectiveLimit + 1,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      status: true,
      createdAt: true,
      expiresAt: true,
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
      expiresAt: r.expiresAt,
    };
  });

  const pendingCount = await prisma.connectionRequest.count({
    where: {
      receiverUserId: userId,
      status: RequestStatus.PENDING,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: new Date() } },
      ],
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
  await expireOldRequests();

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

  // Atomic update and Match creation inside transaction
  const result: {
    requestId: string;
    status: string;
    matchId: string;
  } = await prisma.$transaction(async (tx) => {
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

    // Create Match between sender and receiver pet
    const [petAId, petBId] =
      existing.senderPetId < existing.receiverPetId
        ? [existing.senderPetId, existing.receiverPetId]
        : [existing.receiverPetId, existing.senderPetId];

    const match = await tx.match.upsert({
      where: {
        petAId_petBId: { petAId, petBId },
      },
      update: {
        status: MatchStatus.ACTIVE,
        endedAt: null,
        endedBy: null,
      },
      create: {
        petAId,
        petBId,
        status: MatchStatus.ACTIVE,
      },
    });

    return {
      requestId,
      status: "ACCEPTED",
      matchId: match.id,
    };
  });

  // Ensure Firestore conversation after request accept transaction commits
  if (result.status === "ACCEPTED" && result.matchId) {
    try {
      const matchRecord = await prisma.match.findUnique({
        where: { id: result.matchId },
        include: {
          petA: { include: { user: true } },
          petB: { include: { user: true } },
        },
      });
      const uidA = matchRecord?.petA?.user?.firebaseUid;
      const uidB = matchRecord?.petB?.user?.firebaseUid;
      if (uidA && uidB) {
        await ensureConversation(result.matchId, [uidA, uidB]);
      }
    } catch (err) {
      console.error("[MatchingService] Post-accept conversation creation error:", err);
    }
  }

  return result;
};

export const rejectConnectionRequest = async (
  userId: string,
  requestId: string
) => {
  await expireOldRequests();

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
      status: RequestStatus.DECLINED,
      respondedAt: new Date(),
    },
  });

  if (updateResult.count !== 1) {
    throw new AppError("Request has already been responded to", 409);
  }

  return {
    requestId,
    status: "DECLINED",
  };
};

export const getUserMatches = async (userId: string) => {
  // Find all pets owned by this user
  const userPets = await prisma.pet.findMany({
    where: { userId },
    select: { id: true },
  });
  const petIds = userPets.map((p) => p.id);

  if (petIds.length === 0) return [];

  const matches = await prisma.match.findMany({
    where: {
      status: MatchStatus.ACTIVE,
      OR: [
        { petAId: { in: petIds } },
        { petBId: { in: petIds } },
      ],
    },
    include: {
      petA: {
        include: {
          user: { include: { profile: true } },
          images: { where: { isMain: true } },
        },
      },
      petB: {
        include: {
          user: { include: { profile: true } },
          images: { where: { isMain: true } },
        },
      },
    },
    orderBy: { createdAt: "desc" },
  });

  // Find blocks involving this user
  const userBlocks = await prisma.userBlock.findMany({
    where: {
      OR: [{ blockerId: userId }, { blockedId: userId }],
    },
  });
  const blockedUserIds = new Set<string>();
  for (const b of userBlocks) {
    if (b.blockerId === userId) blockedUserIds.add(b.blockedId);
    if (b.blockedId === userId) blockedUserIds.add(b.blockerId);
  }

  const activeMatches = matches.filter((m) => {
    const isPetAOwner = petIds.includes(m.petAId);
    const otherOwnerId = isPetAOwner ? m.petB.userId : m.petA.userId;
    return !blockedUserIds.has(otherOwnerId);
  });

  return activeMatches.map((m) => {
    const isPetAOwner = petIds.includes(m.petAId);
    const myPet = isPetAOwner ? m.petA : m.petB;
    const otherPet = isPetAOwner ? m.petB : m.petA;
    const otherOwner = otherPet.user;
    const otherProfile = otherOwner.profile;

    const otherPetPhoto =
      otherPet.imageUrl ||
      otherPet.profilePictureUrl ||
      (otherPet.images?.[0]?.imageUrl ?? null);

    const otherOwnerPhoto =
      otherProfile?.imageUrl ||
      (otherProfile?.profilePictureUrl ?? null);

    const myPetPhoto =
      myPet.imageUrl ||
      myPet.profilePictureUrl ||
      (myPet.images?.[0]?.imageUrl ?? null);

    return {
      matchId: m.id,
      matchedAt: m.createdAt,
      myPet: {
        id: myPet.id,
        name: myPet.name,
        imageUrl: myPetPhoto,
      },
      otherPet: {
        id: otherPet.id,
        name: otherPet.name,
        breed: otherPet.breed,
        species: otherPet.animalType,
        imageUrl: otherPetPhoto,
      },
      otherOwner: {
        id: otherOwner.id,
        name:
          otherProfile?.fullName ||
          (otherOwner.email ? otherOwner.email.split("@")[0] : "Pet Owner"),
        imageUrl: otherOwnerPhoto,
        location: otherProfile?.location || otherProfile?.area || "Nearby",
      },
      lastMessage: "🐾 It's a match! Say hello 👋",
      lastMessageTime: m.createdAt,
    };
  });
};

export const getMatchChat = async (userId: string, matchId: string) => {
  const match = await prisma.match.findUnique({
    where: { id: matchId },
    include: {
      petA: { include: { user: true } },
      petB: { include: { user: true } },
    },
  });

  if (!match) {
    throw new AppError("Match not found or chat not accessible", 404);
  }

  // Caller must own petA or petB
  const isOwnerA = match.petA.userId === userId;
  const isOwnerB = match.petB.userId === userId;
  if (!isOwnerA && !isOwnerB) {
    throw new AppError("Match not found or chat not accessible", 404);
  }

  // Match must be active
  if (match.status !== MatchStatus.ACTIVE) {
    throw new AppError("Match not found or chat not accessible", 404);
  }

  // Both pet owners must be active accounts
  if (!match.petA.user.isActive || !match.petB.user.isActive) {
    throw new AppError("Match not found or chat not accessible", 404);
  }

  // Verify no block exists between the owners
  const otherUserId = isOwnerA ? match.petB.userId : match.petA.userId;
  const block = await prisma.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: userId, blockedId: otherUserId },
        { blockerId: otherUserId, blockedId: userId },
      ],
    },
  });

  if (block) {
    throw new AppError("Match not found or chat not accessible", 404);
  }

  // Ensure Firestore conversation doc exists
  const uidA = match.petA.user.firebaseUid;
  const uidB = match.petB.user.firebaseUid;
  if (uidA && uidB) {
    await ensureConversation(match.id, [uidA, uidB]);
  }

  return {
    conversationId: match.id,
    status: match.status,
  };
};

export const unmatchMatch = async (userId: string, matchId: string) => {
  const match = await prisma.match.findUnique({
    where: { id: matchId },
    include: {
      petA: true,
      petB: true,
    },
  });

  if (!match) {
    throw new AppError("Match not found", 404);
  }

  const isOwnerA = match.petA.userId === userId;
  const isOwnerB = match.petB.userId === userId;
  if (!isOwnerA && !isOwnerB) {
    throw new AppError("Match not found", 404);
  }

  if (match.status === MatchStatus.ENDED) {
    return { success: true, matchId: match.id };
  }

  await prisma.match.update({
    where: { id: matchId },
    data: {
      status: MatchStatus.ENDED,
      endedAt: new Date(),
      endedBy: userId,
    },
  });

  await endConversation(matchId, "UNMATCHED");

  return { success: true, matchId: match.id };
};

import prisma from "../../config/db.ts";
import {
  SwipeAction,
  RequestStatus,
  MatchStatus,
  PetProfileStatus,
  PetPurpose,
} from "../../generated/prisma/client.ts";

/**
 * Computed matchability rule used by every mating results query:
 * A pet is matchable only if profileStatus = COMPLETE AND isNeutered = false AND purpose is MATING or BOTH.
 */
export const MATCHABLE_PET_WHERE = {
  profileStatus: PetProfileStatus.COMPLETE,
  isNeutered: false,
  purpose: { in: [PetPurpose.MATING, PetPurpose.BOTH] },
};
import { AppError } from "../../middleware/errorHandler.ts";
import matchingConfig from "../../config/matching.config.ts";
import { expireOldRequests } from "./matching.expiry.ts";
import { expireSlotsAndDowngrade } from "../slots/slots.expiry.ts";
import {
  ensureConversation,
  endConversation,
  seedInitialMessage,
} from "../../services/firestore.service.ts";
import { NotificationService } from "../../services/notification.service.ts";

export { SwipeAction, RequestStatus, MatchStatus };

async function notifyMatchCreated(matchId: string): Promise<void> {
  try {
    const match = await prisma.match.findUnique({
      where: { id: matchId },
      include: {
        petA: { include: { user: true } },
        petB: { include: { user: true } },
      },
    });
    if (!match || match.status !== MatchStatus.ACTIVE) return;

    // Send to Owner A
    await NotificationService.sendToUser(match.petA.userId, {
      category: "matches",
      type: "match_created",
      title: {
        en: "It's a Match! 🎉",
        ne: "म्याच भयो! 🎉",
      },
      body: {
        en: `Your pet ${match.petA.name} matched with ${match.petB.name}! Say hello 👋`,
        ne: `तपाईंको पाल्तु जनावर ${match.petA.name} ${match.petB.name} सँग म्याच भयो! 👋`,
      },
      data: {
        route: `/chat/${matchId}`,
        matchId,
        otherPetName: match.petB.name,
      },
      collapseKey: `match_${matchId}`,
    });

    // Send to Owner B
    await NotificationService.sendToUser(match.petB.userId, {
      category: "matches",
      type: "match_created",
      title: {
        en: "It's a Match! 🎉",
        ne: "म्याच भयो! 🎉",
      },
      body: {
        en: `Your pet ${match.petB.name} matched with ${match.petA.name}! Say hello 👋`,
        ne: `तपाईंको पाल्तु जनावर ${match.petB.name} ${match.petA.name} सँग म्याच भयो! 👋`,
      },
      data: {
        route: `/chat/${matchId}`,
        matchId,
        otherPetName: match.petA.name,
      },
      collapseKey: `match_${matchId}`,
    });
  } catch (err) {
    console.error("[MatchingService] Failed to send match notifications:", err);
  }
}

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
  // 1. Parallel fetch acting pet and all exclusion queries (Task F: eliminate sequential awaits)
  const cooldownThreshold = new Date(
    Date.now() - matchingConfig.PASS_COOLDOWN_DAYS * 24 * 60 * 60 * 1000
  );

  const [actingPet, petSwipes, relatedRequests, existingMatches] = await Promise.all([
    prisma.pet.findFirst({
      where: { id: actingPetId, userId },
      include: { user: true },
    }),
    prisma.petSwipe.findMany({
      where: {
        swiperPetId: actingPetId,
        OR: [
          { action: SwipeAction.LIKE },
          { action: SwipeAction.PASS, createdAt: { gte: cooldownThreshold } },
        ],
      },
      select: { targetPetId: true },
    }),
    prisma.connectionRequest.findMany({
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
    }),
    prisma.match.findMany({
      where: {
        OR: [{ petAId: actingPetId }, { petBId: actingPetId }],
      },
      select: { petAId: true, petBId: true },
    }),
  ]);

  if (!actingPet) {
    throw new AppError("Acting pet not found or unauthorized", 404);
  }

  if (!actingPet.user.isActive) {
    throw new AppError("Your account is suspended or inactive", 403);
  }

  if (!actingPet.isActive) {
    throw new AppError("Acting pet is inactive. Only active pets can view the deck or swipe.", 400);
  }

  const excludedPetIds = new Set<string>();
  excludedPetIds.add(actingPetId);

  for (const s of petSwipes) {
    excludedPetIds.add(s.targetPetId);
  }
  for (const req of relatedRequests) {
    if (req.senderPetId !== actingPetId) excludedPetIds.add(req.senderPetId);
    if (req.receiverPetId !== actingPetId) excludedPetIds.add(req.receiverPetId);
  }
  for (const m of existingMatches) {
    if (m.petAId !== actingPetId) excludedPetIds.add(m.petAId);
    if (m.petBId !== actingPetId) excludedPetIds.add(m.petBId);
  }

  const allExcludedPetIds = Array.from(excludedPetIds);

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
      // Candidate pet must be active, complete, not neutered, and open to mating
      isActive: true,
      ...MATCHABLE_PET_WHERE,
      name: { not: "" },
      OR: [
        { imageUrl: { not: null } },
        { profilePictureUrl: { not: null } },
        { images: { some: {} } },
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
    const mainGalleryImage =
      p.images?.find((img) => img.isMain && img.imageUrl?.trim())?.imageUrl ||
      p.images?.find((img) => img.imageUrl?.trim())?.imageUrl ||
      "";
    const effectiveImageUrl =
      p.imageUrl?.trim() || p.profilePictureUrl?.trim() || mainGalleryImage || "";
    const allPhotos: string[] = [];
    if (effectiveImageUrl) allPhotos.push(effectiveImageUrl);
    if (p.images && p.images.length > 0) {
      for (const img of p.images) {
        const trimmed = img.imageUrl?.trim();
        if (trimmed && !allPhotos.includes(trimmed)) {
          allPhotos.push(trimmed);
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
  initialMessage?: string;
}

export const recordSwipe = async ({
  userId,
  petId,
  targetPetId,
  action,
  initialMessage,
}: RecordSwipeParams) => {
  if (petId === targetPetId) {
    throw new AppError("A pet cannot swipe on itself", 400);
  }

  if (!Object.values(SwipeAction).includes(action)) {
    throw new AppError(`Invalid swipe action: ${action}. Must be LIKE or PASS`, 400);
  }

  const trimmedIntro =
    typeof initialMessage === "string" && initialMessage.trim().length > 0
      ? initialMessage.trim()
      : null;

  if (trimmedIntro && trimmedIntro.length > 300) {
    throw new AppError("Introductory message must be 300 characters or fewer", 400);
  }

  // Multi-step write wrapped in prisma.$transaction
  const result: {
    status: string;
    matched: boolean;
    matchId?: string;
    requestId?: string;
    swipeId: string;
    targetPetId?: string;
    targetPetName?: string;
    targetPetImageUrl?: string | null;
    targetUserId?: string;
    swiperPetName?: string;
    swiperPetId?: string;
    oppositeRequestId?: string;
    oppositeInitialMessage?: string | null;
    oppositeSenderUserId?: string;
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
          targetPetId: targetPet.id,
          targetPetName: targetPet.name,
          targetPetImageUrl: targetPet.imageUrl || targetPet.profilePictureUrl || null,
          oppositeRequestId: oppositeRequest.id,
          oppositeInitialMessage: oppositeRequest.initialMessage,
          oppositeSenderUserId: oppositeRequest.senderUserId,
        };
      } else {
        // Create new PENDING request with expiresAt
        const expiresAt = new Date(
          Date.now() + matchingConfig.REQUEST_EXPIRY_DAYS * 24 * 60 * 60 * 1000
        );

        const reqRecord = await tx.connectionRequest.upsert({
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
            cancelledAt: null,
            ...(trimmedIntro
              ? { initialMessage: trimmedIntro, initialMessageAt: new Date() }
              : {}),
          },
          create: {
            senderUserId: userId,
            senderPetId: petId,
            receiverUserId: targetPet.userId,
            receiverPetId: targetPetId,
            status: RequestStatus.PENDING,
            expiresAt,
            initialMessage: trimmedIntro,
            initialMessageAt: trimmedIntro ? new Date() : null,
          },
        });

        return {
          status: "recorded",
          matched: false,
          requestId: reqRecord.id,
          swipeId: newSwipe.id,
          targetUserId: targetPet.userId,
          targetPetId: targetPet.id,
          targetPetName: targetPet.name,
          targetPetImageUrl: targetPet.imageUrl || targetPet.profilePictureUrl || null,
          swiperPetName: swiperPet.name,
          swiperPetId: swiperPet.id,
        };
      }
    }

    return {
      status: "recorded",
      matched: false,
      swipeId: newSwipe.id,
      targetUserId: targetPet.userId,
      targetPetId: targetPet.id,
      targetPetName: targetPet.name,
      targetPetImageUrl: targetPet.imageUrl || targetPet.profilePictureUrl || null,
      swiperPetName: swiperPet.name,
      swiperPetId: swiperPet.id,
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
        if (result.oppositeInitialMessage && result.oppositeRequestId && matchRecord) {
          const senderUid =
            matchRecord.petA.userId === result.oppositeSenderUserId ? uidA : uidB;
          const receiverUid = senderUid === uidA ? uidB : uidA;
          await seedInitialMessage(
            result.matchId,
            senderUid,
            receiverUid,
            result.oppositeInitialMessage,
            result.oppositeRequestId
          );
        }
      }
      await notifyMatchCreated(result.matchId);
    } catch (err) {
      console.error("[MatchingService] Post-swipe conversation creation error:", err);
    }
  } else if (action === SwipeAction.LIKE && !result.matched && result.targetUserId) {
    // Notify receiver of new connection request
    try {
      await NotificationService.sendToUser((result as any).targetUserId, {
        category: "requests",
        type: "connection_request",
        title: {
          en: "New Match Request! 🐾",
          ne: "नयाँ म्याच अनुरोध! 🐾",
        },
        body: {
          en: `${(result as any).swiperPetName} sent your pet a connection request!`,
          ne: `${(result as any).swiperPetName} ले तपाईंको पाल्तु जनावरलाई अनुरोध पठायो!`,
        },
        data: {
          route: "/requests",
          senderPetId: (result as any).swiperPetId,
          receiverPetId: (result as any).targetPetId,
        },
      });
    } catch (err) {
      console.error("[MatchingService] Notification error for match request:", err);
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

export const resetPassSwipes = async ({
  userId,
  petId,
}: UndoSwipeParams) => {
  const actingPet = await prisma.pet.findFirst({
    where: { id: petId, userId },
  });
  if (!actingPet) {
    throw new AppError("Acting pet not found or unauthorized", 404);
  }

  const deleted = await prisma.petSwipe.deleteMany({
    where: {
      swiperPetId: petId,
      action: SwipeAction.PASS,
    },
  });

  return {
    success: true,
    clearedCount: deleted.count,
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
  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  const whereClause = {
    receiverUserId: userId,
    status: RequestStatus.PENDING,
    OR: [
      { expiresAt: null },
      { expiresAt: { gt: new Date() } },
    ],
  };

  const [requests, pendingCount] = await Promise.all([
    prisma.connectionRequest.findMany({
      where: whereClause,
      take: effectiveLimit + 1,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      select: {
        id: true,
        status: true,
        initialMessage: true,
        initialMessageAt: true,
        createdAt: true,
        expiresAt: true,
        senderPet: {
          select: {
            id: true,
            name: true,
            imageUrl: true,
            profilePictureUrl: true,
            breed: true,
            animalType: true,
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
            imageUrl: true,
            profilePictureUrl: true,
          },
        },
      },
    }),
    prisma.connectionRequest.count({
      where: whereClause,
    }),
  ]);

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
    const senderOwnerPhoto =
      senderProfile?.imageUrl || senderProfile?.profilePictureUrl || null;
    const receiverPetPhoto =
      r.receiverPet.imageUrl || r.receiverPet.profilePictureUrl || null;

    return {
      id: r.id,
      senderUserId: r.senderUser.id,
      senderUsername,
      senderOwnerImageUrl: senderOwnerPhoto,
      senderPetId: r.senderPet.id,
      senderPetName: r.senderPet.name,
      senderPetImageUrl: senderPetPhoto,
      senderPetBreed: r.senderPet.breed || "",
      senderPetSpecies: r.senderPet.animalType || "",
      receiverPetId: r.receiverPet.id,
      receiverPetName: r.receiverPet.name,
      receiverPetImageUrl: receiverPetPhoto,
      initialMessage: r.initialMessage,
      initialMessageAt: r.initialMessageAt,
      status: r.status,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
    };
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
      if (uidA && uidB && matchRecord) {
        await ensureConversation(result.matchId, [uidA, uidB]);
        if (existing.initialMessage && existing.initialMessage.trim().length > 0) {
          const senderUid =
            matchRecord.petA.userId === existing.senderUserId ? uidA : uidB;
          const receiverUid = senderUid === uidA ? uidB : uidA;
          await seedInitialMessage(
            result.matchId,
            senderUid,
            receiverUid,
            existing.initialMessage,
            existing.id
          );
        }
      }
      await notifyMatchCreated(result.matchId);
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
  // Parallel fetch matches and user blocks directly via pet owner relations (Task F: eliminate sequential awaits)
  const [matches, userBlocks] = await Promise.all([
    prisma.match.findMany({
      where: {
        status: MatchStatus.ACTIVE,
        OR: [
          { petA: { userId } },
          { petB: { userId } },
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
    }),
    prisma.userBlock.findMany({
      where: {
        OR: [{ blockerId: userId }, { blockedId: userId }],
      },
      select: { blockerId: true, blockedId: true },
    }),
  ]);

  if (matches.length === 0) return [];

  const blockedUserIds = new Set<string>();
  for (const b of userBlocks) {
    if (b.blockerId === userId) blockedUserIds.add(b.blockedId);
    if (b.blockedId === userId) blockedUserIds.add(b.blockerId);
  }

  const activeMatches = matches.filter((m) => {
    const isPetAOwner = m.petA.userId === userId;
    const otherOwnerId = isPetAOwner ? m.petB.userId : m.petA.userId;
    return !blockedUserIds.has(otherOwnerId);
  });

  return activeMatches.map((m) => {
    const isPetAOwner = m.petA.userId === userId;
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

  // Ensure Firestore conversation doc exists (non-blocking so chat session retrieval returns instantly)
  const uidA = match.petA.user.firebaseUid;
  const uidB = match.petB.user.firebaseUid;
  if (uidA && uidB) {
    ensureConversation(match.id, [uidA, uidB]).catch((err) => {
      console.warn(`[MatchingService] Background ensureConversation warning for ${match.id}:`, err?.message || err);
    });
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

export interface OutgoingRequestsParams {
  userId: string;
  cursor?: string;
  limit?: number;
}

export const getOutgoingRequests = async ({
  userId,
  cursor,
  limit = 50,
}: OutgoingRequestsParams) => {
  await expireOldRequests();

  const effectiveLimit = Math.min(Math.max(limit, 1), 50);

  const requests = await prisma.connectionRequest.findMany({
    where: {
      senderUserId: userId,
    },
    take: effectiveLimit + 1,
    ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      status: true,
      initialMessage: true,
      initialMessageAt: true,
      createdAt: true,
      respondedAt: true,
      cancelledAt: true,
      expiresAt: true,
      senderPet: {
        select: {
          id: true,
          name: true,
          imageUrl: true,
          profilePictureUrl: true,
        },
      },
      receiverPet: {
        select: {
          id: true,
          name: true,
          breed: true,
          animalType: true,
          imageUrl: true,
          profilePictureUrl: true,
        },
      },
      receiverUser: {
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
    },
  });

  let nextCursor: string | null = null;
  if (requests.length > effectiveLimit) {
    const extra = requests.pop()!;
    nextCursor = extra.id;
  }

  // Resolve matchIds for ACCEPTED requests
  const acceptedPairs = requests
    .filter((r) => r.status === RequestStatus.ACCEPTED)
    .map((r) => {
      const [petAId, petBId] =
        r.senderPet.id < r.receiverPet.id
          ? [r.senderPet.id, r.receiverPet.id]
          : [r.receiverPet.id, r.senderPet.id];
      return { petAId, petBId };
    });

  const matchMap = new Map<string, string>();
  if (acceptedPairs.length > 0) {
    const matches = await prisma.match.findMany({
      where: {
        status: MatchStatus.ACTIVE,
        OR: acceptedPairs,
      },
      select: { id: true, petAId: true, petBId: true },
    });
    for (const m of matches) {
      matchMap.set(`${m.petAId}_${m.petBId}`, m.id);
    }
  }

  const items = requests.map((r) => {
    const receiverProfile = r.receiverUser.profile;
    const receiverOwnerName =
      receiverProfile?.fullName || receiverProfile?.username || "Pet Parent";
    const receiverOwnerImageUrl =
      receiverProfile?.imageUrl || receiverProfile?.profilePictureUrl || null;
    const receiverPetImageUrl =
      r.receiverPet.imageUrl || r.receiverPet.profilePictureUrl || null;
    const senderPetImageUrl =
      r.senderPet.imageUrl || r.senderPet.profilePictureUrl || null;

    const [petAId, petBId] =
      r.senderPet.id < r.receiverPet.id
        ? [r.senderPet.id, r.receiverPet.id]
        : [r.receiverPet.id, r.senderPet.id];
    const matchId =
      r.status === RequestStatus.ACCEPTED
        ? matchMap.get(`${petAId}_${petBId}`) ?? null
        : null;

    return {
      id: r.id,
      senderPetId: r.senderPet.id,
      senderPetName: r.senderPet.name,
      senderPetImageUrl,
      receiverUserId: r.receiverUser.id,
      receiverOwnerName,
      receiverOwnerImageUrl,
      receiverPetId: r.receiverPet.id,
      receiverPetName: r.receiverPet.name,
      receiverPetBreed: r.receiverPet.breed || "",
      receiverPetSpecies: r.receiverPet.animalType || "",
      receiverPetImageUrl,
      initialMessage: r.initialMessage,
      initialMessageAt: r.initialMessageAt,
      status: r.status,
      matchId,
      createdAt: r.createdAt,
      respondedAt: r.respondedAt,
      cancelledAt: r.cancelledAt,
      expiresAt: r.expiresAt,
    };
  });

  return {
    requests: items,
    nextCursor,
    hasMore: Boolean(nextCursor),
  };
};

export const updateInitialMessage = async (
  userId: string,
  requestId: string,
  message: string
) => {
  await expireOldRequests();

  const trimmed = message.trim();
  if (!trimmed) {
    throw new AppError("Introductory message cannot be empty", 400);
  }
  if (trimmed.length > 300) {
    throw new AppError("Introductory message must be 300 characters or fewer", 400);
  }

  const existing = await prisma.connectionRequest.findUnique({
    where: { id: requestId },
    include: {
      senderPet: { select: { name: true } },
    },
  });

  if (!existing) {
    throw new AppError("Connection request not found", 404);
  }

  if (existing.senderUserId !== userId) {
    throw new AppError(
      "Access forbidden: you are not the sender of this request",
      403
    );
  }

  if (existing.status !== RequestStatus.PENDING) {
    throw new AppError(
      `Cannot update introductory message because the request is ${existing.status.toLowerCase()}`,
      409
    );
  }

  const hadPreviousMessage = Boolean(
    existing.initialMessage && existing.initialMessage.trim().length > 0
  );

  const updated = await prisma.connectionRequest.update({
    where: { id: requestId },
    data: {
      initialMessage: trimmed,
      initialMessageAt: new Date(),
    },
  });

  // Notify receiver only when an intro message is added for the first time
  if (!hadPreviousMessage) {
    try {
      await NotificationService.sendToUser(existing.receiverUserId, {
        category: "requests",
        type: "connection_request_message",
        title: {
          en: `Message from ${existing.senderPet.name} 💬`,
          ne: `${existing.senderPet.name} बाट सन्देश 💬`,
        },
        body: {
          en: trimmed.length > 80 ? `${trimmed.slice(0, 77)}...` : trimmed,
          ne: trimmed.length > 80 ? `${trimmed.slice(0, 77)}...` : trimmed,
        },
        data: {
          route: `/request/${requestId}`,
          requestId,
        },
      });
    } catch (err) {
      console.error("[MatchingService] Intro message notification error:", err);
    }
  }

  return {
    requestId: updated.id,
    initialMessage: updated.initialMessage,
    initialMessageAt: updated.initialMessageAt,
  };
};

export const cancelConnectionRequest = async (
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

  if (existing.senderUserId !== userId) {
    throw new AppError(
      "Access forbidden: you are not the sender of this request",
      403
    );
  }

  if (existing.status !== RequestStatus.PENDING) {
    throw new AppError(
      `Request has already been ${existing.status.toLowerCase()}`,
      409
    );
  }

  await prisma.connectionRequest.updateMany({
    where: {
      id: requestId,
      senderUserId: userId,
      status: RequestStatus.PENDING,
    },
    data: {
      status: RequestStatus.CANCELLED,
      cancelledAt: new Date(),
    },
  });

  return {
    requestId,
    status: "CANCELLED",
  };
};

export const getAllConnectionInteractions = async (userId: string) => {
  await expireOldRequests();

  const [matches, incoming, outgoing] = await Promise.all([
    getUserMatches(userId),
    getIncomingRequests({ userId, limit: 50 }),
    getOutgoingRequests({ userId, limit: 50 }),
  ]);

  const activeMatchIds = new Set(matches.map((m) => m.matchId));

  type UnifiedItem = {
    itemType: "ACTIVE_CHAT" | "INCOMING_REQUEST" | "OUTGOING_REQUEST";
    id: string;
    sortAt: string;
    match?: any;
    incomingRequest?: any;
    outgoingRequest?: any;
  };

  const items: UnifiedItem[] = [];

  for (const m of matches) {
    items.push({
      itemType: "ACTIVE_CHAT",
      id: `match_${m.matchId}`,
      sortAt: new Date(m.lastMessageTime || m.matchedAt).toISOString(),
      match: m,
    });
  }

  for (const req of incoming.requests) {
    items.push({
      itemType: "INCOMING_REQUEST",
      id: `in_${req.id}`,
      sortAt: new Date(req.initialMessageAt || req.createdAt).toISOString(),
      incomingRequest: req,
    });
  }

  for (const req of outgoing.requests) {
    // Avoid duplicating accepted requests that are already shown as ACTIVE_CHAT
    if (req.status === "ACCEPTED" && req.matchId && activeMatchIds.has(req.matchId)) {
      continue;
    }
    items.push({
      itemType: "OUTGOING_REQUEST",
      id: `out_${req.id}`,
      sortAt: new Date(
        req.respondedAt || req.cancelledAt || req.initialMessageAt || req.createdAt
      ).toISOString(),
      outgoingRequest: req,
    });
  }

  items.sort((a, b) => new Date(b.sortAt).getTime() - new Date(a.sortAt).getTime());

  return { items };
};

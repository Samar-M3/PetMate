import crypto from "crypto";
import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import {
  calculateAgeInMonths,
  calculateAgeString,
} from "../matching/matching.service.ts";

const EARTH_RADIUS_KM = 6371.0;
const DEFAULT_FRESHNESS_DAYS = 30;

function getLocationFreshnessCutoff(): Date {
  const rawDays = Number(process.env.LOCATION_FRESHNESS_DAYS);
  const days =
    Number.isFinite(rawDays) && rawDays > 0 ? rawDays : DEFAULT_FRESHNESS_DAYS;
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

/**
 * Haversine formula returning great-circle distance in kilometers.
 */
export function calculateHaversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_KM * c;
}

/**
 * Computes a bounding box (min/max lat & lng) for efficient SQL prefiltering.
 */
export function computeBoundingBox(
  lat: number,
  lng: number,
  radiusKm: number
) {
  const latDelta = radiusKm / 111.32;
  const cosLat = Math.max(0.1, Math.cos((lat * Math.PI) / 180));
  const lngDelta = radiusKm / (111.32 * cosLat);

  return {
    minLat: Math.max(-90, lat - latDelta),
    maxLat: Math.min(90, lat + latDelta),
    minLng: Math.max(-180, lng - lngDelta),
    maxLng: Math.min(180, lng + lngDelta),
  };
}

/**
 * Generates privacy-preserving approximate coordinates for map rendering.
 * Quantizes to ~1.1km grid and applies a deterministic per-owner offset (~350m)
 * so actual GPS coordinates are never exposed or reverse-engineered.
 */
export function anonymizeCoordinates(
  lat: number,
  lng: number,
  seed: string
): { latitude: number; longitude: number } {
  const gridLat = Math.round(lat * 100) / 100;
  const gridLng = Math.round(lng * 100) / 100;

  const hash = crypto.createHash("sha256").update(seed).digest();
  const latOffset = ((hash[0] / 255) - 0.5) * 0.007;
  const lngOffset = ((hash[1] / 255) - 0.5) * 0.007;

  return {
    latitude: Number((gridLat + latOffset).toFixed(4)),
    longitude: Number((gridLng + lngOffset).toFixed(4)),
  };
}

export const updateAuthenticatedOwnerLocation = async (params: {
  userId: string;
  latitude: number;
  longitude: number;
  area?: string | null;
  locationEnabled?: boolean;
}) => {
  const { userId, latitude, longitude, area, locationEnabled } = params;
  const now = new Date();
  const trimmedArea = area?.trim() || undefined;

  const existing = await prisma.profile.findUnique({
    where: { userId },
    select: { locationEnabled: true, area: true },
  });

  // Enable discovery on first explicit share unless caller explicitly passes false
  const nextVisibility =
    locationEnabled !== undefined
      ? locationEnabled
      : existing?.locationEnabled ?? true;

  const updated = await prisma.profile.upsert({
    where: { userId },
    update: {
      latitude,
      longitude,
      locationUpdatedAt: now,
      locationEnabled: nextVisibility,
      ...(trimmedArea ? { area: trimmedArea } : {}),
    },
    create: {
      userId,
      latitude,
      longitude,
      locationUpdatedAt: now,
      locationEnabled: nextVisibility,
      area: trimmedArea ?? null,
    },
    select: {
      area: true,
      city: true,
      district: true,
      locationEnabled: true,
      locationUpdatedAt: true,
    },
  });

  const approx = anonymizeCoordinates(latitude, longitude, userId);

  return {
    locationEnabled: updated.locationEnabled,
    locationUpdatedAt: updated.locationUpdatedAt,
    area: updated.area || [updated.city, updated.district].filter(Boolean).join(", ") || null,
    approxLocation: approx,
  };
};

export const updateAuthenticatedOwnerVisibility = async (
  userId: string,
  locationEnabled: boolean
) => {
  const updated = await prisma.profile.upsert({
    where: { userId },
    update: { locationEnabled },
    create: {
      userId,
      locationEnabled,
    },
    select: {
      locationEnabled: true,
      locationUpdatedAt: true,
      area: true,
    },
  });

  return updated;
};

export const getNearbyOwners = async (params: {
  userId: string;
  radius: number;
  page: number;
  limit: number;
}) => {
  const { userId, radius, page, limit } = params;

  // 1. Fetch requesting user's stored location
  const requesterProfile = await prisma.profile.findUnique({
    where: { userId },
    select: {
      latitude: true,
      longitude: true,
      locationEnabled: true,
      locationUpdatedAt: true,
      area: true,
      city: true,
      district: true,
    },
  });

  if (
    !requesterProfile ||
    requesterProfile.latitude === null ||
    requesterProfile.longitude === null
  ) {
    throw new AppError(
      "Location is not set. Please share your location or choose an area first.",
      400
    );
  }

  const userLat = requesterProfile.latitude;
  const userLng = requesterProfile.longitude;
  const freshnessCutoff = getLocationFreshnessCutoff();
  const bbox = computeBoundingBox(userLat, userLng, radius);

  // 2. Bounding-box prefilter + privacy/block/active exclusions in DB
  const candidates = await prisma.profile.findMany({
    where: {
      userId: { not: userId },
      locationEnabled: true,
      latitude: { gte: bbox.minLat, lte: bbox.maxLat },
      longitude: { gte: bbox.minLng, lte: bbox.maxLng },
      locationUpdatedAt: { gte: freshnessCutoff },
      user: {
        isActive: true,
        blocksGiven: { none: { blockedId: userId } },
        blocksReceived: { none: { blockerId: userId } },
        pets: { some: { isActive: true } },
      },
    },
    select: {
      userId: true,
      displayName: true,
      fullName: true,
      username: true,
      profilePictureUrl: true,
      imageUrl: true,
      avatarUrl: true,
      area: true,
      city: true,
      district: true,
      latitude: true,
      longitude: true,
      user: {
        select: {
          id: true,
          pets: {
            where: { isActive: true },
            orderBy: { createdAt: "desc" },
            select: {
              id: true,
              name: true,
              species: true,
              speciesOther: true,
              animalType: true,
              breed: true,
              gender: true,
              dateOfBirth: true,
              imageUrl: true,
              profilePictureUrl: true,
              images: {
                orderBy: [{ position: "asc" }, { createdAt: "asc" }],
                take: 1,
                select: { imageUrl: true },
              },
            },
          },
        },
      },
    },
  });

  // 3. Exact Haversine distance calculation & radius filter
  const withinRadius = candidates
    .map((candidate) => {
      if (candidate.latitude === null || candidate.longitude === null) {
        return null;
      }
      const distanceKm = calculateHaversineKm(
        userLat,
        userLng,
        candidate.latitude,
        candidate.longitude
      );
      if (distanceKm > radius) return null;

      const roundedDistance = Math.max(0.1, Number(distanceKm.toFixed(1)));
      const approx = anonymizeCoordinates(
        candidate.latitude,
        candidate.longitude,
        candidate.userId
      );

      const displayName =
        candidate.displayName?.trim() ||
        candidate.fullName?.trim() ||
        candidate.username?.trim() ||
        "Pet Parent";

      const profileImage =
        candidate.avatarUrl ||
        candidate.profilePictureUrl ||
        candidate.imageUrl ||
        null;

      const areaLabel =
        candidate.area?.trim() ||
        [candidate.city, candidate.district].filter(Boolean).join(", ") ||
        "Nearby";

      const pets = candidate.user.pets.map((pet) => {
        const ageMonths = calculateAgeInMonths(pet.dateOfBirth);
        const ageYears = Math.floor(ageMonths / 12);
        const remMonths = ageMonths % 12;
        const numericAge = Number(`${ageYears}.${remMonths}`);
        const animalType =
          pet.speciesOther?.trim() ||
          pet.animalType?.trim() ||
          pet.species ||
          "Pet";
        const petImage =
          pet.imageUrl ||
          pet.profilePictureUrl ||
          pet.images[0]?.imageUrl ||
          null;

        return {
          id: pet.id,
          name: pet.name,
          animalType,
          breed: pet.breed || "Mixed",
          age: numericAge,
          ageString: calculateAgeString(pet.dateOfBirth),
          gender: pet.gender || "Unknown",
          image: petImage,
        };
      });

      if (pets.length === 0) return null;

      return {
        ownerId: candidate.userId,
        displayName,
        profileImage,
        area: areaLabel,
        distanceKm: roundedDistance,
        approxLocation: approx,
        pets,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null)
    .sort((a, b) => a.distanceKm - b.distanceKm);

  const total = withinRadius.length;
  const start = (page - 1) * limit;
  const paginatedOwners = withinRadius.slice(start, start + limit);

  // 4. Privacy-preserving aggregated clusters (~2.2km grid) for map rendering
  const clusterMap = new Map<
    string,
    {
      clusterId: string;
      latitude: number;
      longitude: number;
      ownerCount: number;
      areaLabel: string;
    }
  >();

  for (const owner of paginatedOwners) {
    const cLat = Number((Math.round(owner.approxLocation.latitude * 50) / 50).toFixed(4));
    const cLng = Number((Math.round(owner.approxLocation.longitude * 50) / 50).toFixed(4));
    const key = `${cLat}_${cLng}`;
    const existing = clusterMap.get(key);
    if (existing) {
      existing.ownerCount += 1;
    } else {
      clusterMap.set(key, {
        clusterId: key,
        latitude: cLat,
        longitude: cLng,
        ownerCount: 1,
        areaLabel: owner.area,
      });
    }
  }

  const requesterApprox = anonymizeCoordinates(userLat, userLng, userId);

  return {
    total,
    page,
    limit,
    radius,
    currentUser: {
      locationEnabled: requesterProfile.locationEnabled,
      locationUpdatedAt: requesterProfile.locationUpdatedAt,
      area:
        requesterProfile.area ||
        [requesterProfile.city, requesterProfile.district]
          .filter(Boolean)
          .join(", ") ||
        null,
      approxLocation: requesterApprox,
    },
    clusters: Array.from(clusterMap.values()),
    owners: paginatedOwners,
  };
};

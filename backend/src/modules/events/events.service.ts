import prisma from "../../config/db.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import type {
  Event,
  EventBookmark,
  EventRsvp,
} from "../../generated/prisma/client.ts";

type EventWithUserRows = Event & {
  rsvps?: EventRsvp[];
  bookmarks?: EventBookmark[];
};

/**
 * Adds the per-user flags the app needs. They are derived from rows filtered
 * by `userId`, so one account's bookings can never leak into another's view.
 */
export const toClientEvent = (event: EventWithUserRows, userId?: string) => {
  const { rsvps, bookmarks, ...rest } = event;
  return {
    ...rest,
    isBooked: userId ? (rsvps ?? []).some((r) => r.userId === userId) : false,
    isBookmarked: userId
      ? (bookmarks ?? []).some((b) => b.userId === userId)
      : false,
  };
};

/** Accepts only real booleans — `"false"` must not be treated as `true`. */
export const parseEventFlag = (value: unknown): boolean | null =>
  typeof value === "boolean" ? value : null;

export const listEvents = async (userId?: string) => {
  const events = await prisma.event.findMany({
    include: userId
      ? {
          rsvps: { where: { userId } },
          bookmarks: { where: { userId } },
        }
      : undefined,
    orderBy: { createdAt: "desc" },
  });

  return events.map((event) => toClientEvent(event, userId));
};

export const updateEventBookmark = async (
  userId: string,
  eventId: string,
  isBookmarked: boolean
) => {
  return prisma.$transaction(async (tx) => {
    const event = await tx.event.findUnique({
      where: { id: eventId },
      select: { id: true },
    });
    if (!event) throw new AppError("Event not found", 404);

    if (isBookmarked) {
      await tx.eventBookmark.upsert({
        where: { userId_eventId: { userId, eventId } },
        update: {},
        create: { userId, eventId },
      });
    } else {
      await tx.eventBookmark.deleteMany({ where: { userId, eventId } });
    }

    const updated = await tx.event.findUnique({
      where: { id: eventId },
      include: {
        rsvps: { where: { userId } },
        bookmarks: { where: { userId } },
      },
    });
    if (!updated) throw new AppError("Event not found", 404);

    return toClientEvent(updated, userId);
  });
};

export const updateEventRsvp = async (
  userId: string,
  eventId: string,
  isBooked: boolean
) => {
  return prisma.$transaction(async (tx) => {
    const event = await tx.event.findUnique({
      where: { id: eventId },
      select: { id: true },
    });
    if (!event) throw new AppError("Event not found", 404);

    // Upsert/deleteMany keep this idempotent even if two devices send the
    // same request at once; the unique (userId, eventId) index prevents
    // duplicate spots.
    if (isBooked) {
      await tx.eventRsvp.upsert({
        where: { userId_eventId: { userId, eventId } },
        update: {},
        create: { userId, eventId },
      });
    } else {
      await tx.eventRsvp.deleteMany({ where: { userId, eventId } });
    }

    // Attendee count is always recalculated from the source of truth.
    const attendeeCount = await tx.eventRsvp.count({ where: { eventId } });
    await tx.event.update({
      where: { id: eventId },
      data: { attendeeCount },
    });

    const updated = await tx.event.findUnique({
      where: { id: eventId },
      include: {
        rsvps: { where: { userId } },
        bookmarks: { where: { userId } },
      },
    });
    if (!updated) throw new AppError("Event not found", 404);

    return toClientEvent(updated, userId);
  });
};

export const createEvent = async (data: {
  title: string;
  category?: string;
  dayName?: string;
  dayNum?: string;
  fullDate: string;
  time: string;
  location: string;
  description: string;
  attendeeCount?: number;
}) => {
  return prisma.event.create({
    data: {
      title: data.title,
      category: data.category || "MEETUP",
      dayName: data.dayName,
      dayNum: data.dayNum,
      fullDate: data.fullDate,
      time: data.time,
      location: data.location,
      description: data.description,
      attendeeCount: data.attendeeCount || 0,
    },
  });
};

export const deleteEvent = async (id: string) => {
  return prisma.event.delete({ where: { id } });
};

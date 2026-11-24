import prisma from "../../config/db.ts";

async function getOrCreatePostgresUserId(firebaseUid: string, email?: string): Promise<string> {
  let user = await prisma.user.findUnique({
    where: { firebaseUid },
  });
  if (!user) {
    user = await prisma.user.create({
      data: {
        firebaseUid,
        email: email || null,
        role: "PET_OWNER",
        isActive: true,
      },
    });
  }
  return user.id;
}

export const listEvents = async (pgUserId?: string, firebaseUid?: string, email?: string) => {
  let resolvedUserId = pgUserId;
  if (!resolvedUserId && firebaseUid) {
    resolvedUserId = await getOrCreatePostgresUserId(firebaseUid, email);
  }

  const events = await prisma.event.findMany({
    include: {
      rsvps: resolvedUserId ? { where: { userId: resolvedUserId } } : false,
      bookmarks: resolvedUserId ? { where: { userId: resolvedUserId } } : false,
    },
    orderBy: { createdAt: "desc" },
  });

  return events.map((event) => {
    const isBooked = resolvedUserId ? (event.rsvps as any[]).length > 0 : false;
    const isBookmarked = resolvedUserId ? (event.bookmarks as any[]).length > 0 : false;
    const { rsvps, bookmarks, ...rest } = event;
    return {
      ...rest,
      isBooked,
      isBookmarked,
    };
  });
};

export const updateEventBookmark = async (firebaseUid: string, eventId: string, isBookmarked: boolean, email?: string) => {
  const userId = await getOrCreatePostgresUserId(firebaseUid, email);

  if (isBookmarked) {
    await prisma.eventBookmark.upsert({
      where: { userId_eventId: { userId, eventId } },
      update: {},
      create: { userId, eventId },
    });
  } else {
    await prisma.eventBookmark.deleteMany({
      where: { userId, eventId },
    });
  }

  const event = await prisma.event.findUnique({
    where: { id: eventId },
    include: {
      rsvps: { where: { userId } },
      bookmarks: { where: { userId } },
    },
  });

  if (!event) throw new Error("Event not found");

  return {
    ...event,
    isBooked: event.rsvps.length > 0,
    isBookmarked: event.bookmarks.length > 0,
  };
};

export const updateEventRsvp = async (firebaseUid: string, eventId: string, isBooked: boolean, email?: string) => {
  const userId = await getOrCreatePostgresUserId(firebaseUid, email);

  if (isBooked) {
    await prisma.eventRsvp.upsert({
      where: { userId_eventId: { userId, eventId } },
      update: {},
      create: { userId, eventId },
    });
  } else {
    await prisma.eventRsvp.deleteMany({
      where: { userId, eventId },
    });
  }

  // Recalculate true attendee count from RSVPs table
  const attendeeCount = await prisma.eventRsvp.count({ where: { eventId } });
  await prisma.event.update({
    where: { id: eventId },
    data: { attendeeCount },
  });

  const event = await prisma.event.findUnique({
    where: { id: eventId },
    include: {
      rsvps: { where: { userId } },
      bookmarks: { where: { userId } },
    },
  });

  if (!event) throw new Error("Event not found");

  return {
    ...event,
    attendeeCount,
    isBooked: event.rsvps.length > 0,
    isBookmarked: event.bookmarks.length > 0,
  };
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

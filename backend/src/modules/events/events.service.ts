import prisma from "../../config/db.ts";

export const listEvents = async () => {
  return prisma.event.findMany({
    orderBy: { createdAt: "desc" },
  });
};

export const updateEventBookmark = async (id: string, _isBookmarked: boolean) => {
  const event = await prisma.event.findUnique({ where: { id } });
  if (!event) {
    throw new Error("Event not found");
  }
  return event;
};

export const updateEventRsvp = async (id: string, isBooked: boolean) => {
  const event = await prisma.event.findUnique({ where: { id } });
  if (!event) {
    throw new Error("Event not found");
  }
  const attendeeCount = Math.max(0, event.attendeeCount + (isBooked ? 1 : -1));
  return prisma.event.update({
    where: { id },
    data: { attendeeCount },
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

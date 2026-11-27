import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { toClientEvent, parseEventFlag } from "../src/modules/events/events.service.ts";

const event = {
  id: "event-1",
  title: "Pet Meetup",
  category: "MEETUP",
  fullDate: "Dec 05, 2026",
  time: "10:00 AM",
  location: "Kathmandu",
  description: "A meetup",
  attendeeCount: 1,
  createdAt: new Date("2026-11-01"),
  updatedAt: new Date("2026-11-01"),
};

describe("Events: per-user state", () => {
  test("booking and bookmark flags come only from the current user's rows", () => {
    const result = toClientEvent(
      {
        ...event,
        rsvps: [{ id: "r1", userId: "user-a", eventId: event.id, createdAt: new Date() }],
        bookmarks: [],
      } as any,
      "user-a"
    );

    assert.equal(result.isBooked, true);
    assert.equal(result.isBookmarked, false);
    assert.equal(result.attendeeCount, 1);
  });

  test("another user's rows never mark this user's event as booked", () => {
    const rows = {
      ...event,
      rsvps: [{ id: "r1", userId: "user-a", eventId: event.id, createdAt: new Date() }],
      bookmarks: [{ id: "b1", userId: "user-a", eventId: event.id, createdAt: new Date() }],
    } as any;

    const otherUser = toClientEvent(rows, "user-b");
    assert.equal(otherUser.isBooked, false);
    assert.equal(otherUser.isBookmarked, false);

    const guest = toClientEvent(rows);
    assert.equal(guest.isBooked, false);
    assert.equal(guest.isBookmarked, false);
  });

  test("RSVP relations are not leaked to the client", () => {
    const result = toClientEvent(
      { ...event, rsvps: [], bookmarks: [] } as any,
      "user-a"
    );
    assert.equal("rsvps" in result, false);
    assert.equal("bookmarks" in result, false);
  });
});

describe("Events: body validation", () => {
  test("only real booleans are accepted as bookmark/booking flags", () => {
    assert.equal(parseEventFlag(true), true);
    assert.equal(parseEventFlag(false), false);
    assert.equal(parseEventFlag("false"), null);
    assert.equal(parseEventFlag("true"), null);
    assert.equal(parseEventFlag(1), null);
    assert.equal(parseEventFlag(undefined), null);
  });
});

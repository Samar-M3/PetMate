import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import { listEvents, createEvent, deleteEvent, updateEventBookmark, updateEventRsvp } from "./events.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getEvents = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const pgUserId = req.user?.id;
    const firebaseUid = req.firebaseUid || req.user?.firebaseUid;
    const email = req.firebaseUser?.email;
    const events = await listEvents(pgUserId, firebaseUid, email);
    sendSuccess(res, {
      statusCode: 200,
      message: "Events retrieved successfully",
      data: { events },
    });
  } catch (error) {
    next(error);
  }
};

export const bookmarkEvent = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const firebaseUid = req.firebaseUid || req.user?.firebaseUid;
    const email = req.firebaseUser?.email;
    if (!firebaseUid) {
      return next(new AppError("User not authenticated", 401));
    }
    const { id } = req.params;
    const { isBookmarked } = req.body;
    const event = await updateEventBookmark(firebaseUid, id as string, !!isBookmarked, email);
    sendSuccess(res, {
      statusCode: 200,
      message: "Event bookmark updated successfully",
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

export const rsvpEvent = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const firebaseUid = req.firebaseUid || req.user?.firebaseUid;
    const email = req.firebaseUser?.email;
    if (!firebaseUid) {
      return next(new AppError("User not authenticated", 401));
    }
    const { id } = req.params;
    const { isBooked } = req.body;
    const event = await updateEventRsvp(firebaseUid, id as string, !!isBooked, email);
    sendSuccess(res, {
      statusCode: 200,
      message: "Event RSVP/booking functionality successfully updated",
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

export const addEvent = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { title, category, fullDate, time, location, description } = req.body;
    if (!title || !fullDate || !time || !location || !description) {
      return next(
        new AppError(
          "title, fullDate, time, location, and description are required",
          400
        )
      );
    }

    const event = await createEvent(req.body);
    sendSuccess(res, {
      statusCode: 201,
      message: "Event created successfully",
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

export const removeEvent = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    await deleteEvent(id as string);
    sendSuccess(res, {
      statusCode: 200,
      message: "Event deleted successfully",
      data: null,
    });
  } catch (error) {
    next(error);
  }
};

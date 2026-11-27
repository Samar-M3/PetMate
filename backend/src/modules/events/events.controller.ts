import type { Request, Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  listEvents,
  createEvent,
  deleteEvent,
  updateEvent,
  updateEventBookmark,
  updateEventRsvp,
  parseEventFlag,
} from "./events.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getEvents = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // `requireInitializedUser` is not used for reads: guests may browse, but
    // only an authenticated user's own rows are used for the state flags.
    const events = await listEvents(req.user?.id);
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
    if (!req.user) {
      return next(new AppError("User not authenticated", 401));
    }

    const isBookmarked = parseEventFlag(req.body?.isBookmarked);
    if (isBookmarked === null) {
      return next(new AppError("isBookmarked must be a boolean", 400));
    }

    const event = await updateEventBookmark(
      req.user.id,
      req.params.id as string,
      isBookmarked
    );
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
    if (!req.user) {
      return next(new AppError("User not authenticated", 401));
    }

    const isBooked = parseEventFlag(req.body?.isBooked);
    if (isBooked === null) {
      return next(new AppError("isBooked must be a boolean", 400));
    }

    const event = await updateEventRsvp(
      req.user.id,
      req.params.id as string,
      isBooked
    );
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

export const editEvent = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { id } = req.params;
    const { title, category, dayName, dayNum, fullDate, time, location, description } = req.body;

    const event = await updateEvent(id as string, {
      title,
      category,
      dayName,
      dayNum,
      fullDate,
      time,
      location,
      description,
    });

    sendSuccess(res, {
      statusCode: 200,
      message: "Event updated successfully",
      data: { event },
    });
  } catch (error) {
    next(error);
  }
};

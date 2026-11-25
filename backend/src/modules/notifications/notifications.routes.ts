import { Router } from "express";
import { authenticateFirebase, requireInitializedUser } from "../../middleware/auth.middleware.ts";
import {
  registerDeviceController,
  deleteDeviceController,
  getPreferencesController,
  updatePreferencesController,
} from "./notifications.controller.ts";

export const devicesRouter = Router();
devicesRouter.use(authenticateFirebase, requireInitializedUser);
devicesRouter.post("/", registerDeviceController);
devicesRouter.delete("/:token", deleteDeviceController);

export const notificationsRouter = Router();
notificationsRouter.use(authenticateFirebase, requireInitializedUser);
notificationsRouter.get("/preferences", getPreferencesController);
notificationsRouter.patch("/preferences", updatePreferencesController);

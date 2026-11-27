import { Router } from "express";
import {
  getMeProfile,
  putMeProfile,
  postCompleteProfile,
} from "./profile.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

router.use(authenticateFirebase);
router.use(requireInitializedUser);
router.use(requireRole(Role.PET_OWNER, Role.ADMIN));

router.get("/me", getMeProfile);
router.put("/me", putMeProfile);
router.post("/complete", postCompleteProfile);

export default router;

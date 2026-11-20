import { Router } from "express";
import {
  getSummary,
  postCheckout,
  postVerifyPayment,
} from "./slots.controller.ts";
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

// User active-slot management & checkout
router.get("/summary", getSummary);
router.post("/checkout", postCheckout);
router.post("/verify", postVerifyPayment);

export default router;

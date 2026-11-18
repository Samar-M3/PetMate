import { Router } from "express";
import {
  getUsers,
  getUser,
  changeUserRole,
  changeUserStatus,
  getLogs,
} from "./admin.controller.ts";
import {
  authenticateFirebase,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// All admin routes require authentication + initialized user + ADMIN role
router.use(authenticateFirebase);
router.use(requireInitializedUser);
router.use(requireRole(Role.ADMIN));

router.get("/users", getUsers);
router.get("/users/:id", getUser);
router.patch("/users/:id/role", changeUserRole);
router.patch("/users/:id/status", changeUserStatus);
router.get("/audit-logs", getLogs);

export default router;

import { Router } from "express";
import {
  getUsers,
  getUser,
  changeUserRole,
  changeUserStatus,
  getLogs,
  getStats,
  getApplications,
  approveApplication,
  rejectApplication,
} from "./admin.controller.ts";
import {
  authenticateAdmin,
  requireInitializedUser,
  requireRole,
  Role,
} from "../../middleware/auth.middleware.ts";

const router = Router();

// All admin routes require token authentication (with checkRevoked) + initialized user + ADMIN role
router.use(authenticateAdmin);
router.use(requireInitializedUser);
router.use(requireRole(Role.ADMIN));

// Stats
router.get("/stats", getStats);

// Users Management
router.get("/users", getUsers);
router.get("/users/:id", getUser);
router.patch("/users/:id/role", changeUserRole);
router.patch("/users/:id/status", changeUserStatus);

// Role Applications (Vet & Seller approvals)
router.get("/applications", getApplications);
router.post("/applications/:id/approve", approveApplication);
router.post("/applications/:id/reject", rejectApplication);

// Audit logs
router.get("/audit-logs", getLogs);

export default router;

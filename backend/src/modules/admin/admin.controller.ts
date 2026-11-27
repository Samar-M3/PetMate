import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  Role,
  ApplicationStatus,
  ApplicationType,
} from "../../generated/prisma/client.ts";
import {
  listUsers,
  getUserById,
  updateUserRole,
  updateUserStatus,
  getAuditLogs,
  getAdminStats,
  listRoleApplications,
  approveRoleApplication,
  rejectRoleApplication,
} from "./admin.service.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const getUsers = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const search = req.query.search as string | undefined;
    const role = req.query.role as Role | undefined;

    // Validate role if provided
    if (role && !Object.values(Role).includes(role)) {
      return next(new AppError(`Invalid role filter: ${role}`, 400));
    }

    const result = await listUsers({ page, limit, search, role });

    sendSuccess(res, {
      statusCode: 200,
      message: "Users retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getUser = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const user = await getUserById(req.params.id as string);

    sendSuccess(res, {
      statusCode: 200,
      message: "User details retrieved successfully",
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

export const changeUserRole = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { role } = req.body;
    if (!role) {
      return next(new AppError("role is required in the request body", 400));
    }

    if (!Object.values(Role).includes(role)) {
      return next(new AppError(`Invalid role: ${role}. Valid roles: ${Object.values(Role).join(", ")}`, 400));
    }

    const updatedUser = await updateUserRole(
      req.user.id,
      req.params.id as string,
      role as Role
    );

    sendSuccess(res, {
      statusCode: 200,
      message: `User role updated to ${role}`,
      data: { user: updatedUser },
    });
  } catch (error) {
    next(error);
  }
};

export const changeUserStatus = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { isActive } = req.body;
    if (typeof isActive !== "boolean") {
      return next(
        new AppError("isActive (boolean) is required in the request body", 400)
      );
    }

    const updatedUser = await updateUserStatus(
      req.user.id,
      req.params.id as string,
      isActive
    );

    sendSuccess(res, {
      statusCode: 200,
      message: `User ${isActive ? "reactivated" : "deactivated"} successfully`,
      data: { user: updatedUser },
    });
  } catch (error) {
    next(error);
  }
};

export const getLogs = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);

    const result = await getAuditLogs(page, limit);

    sendSuccess(res, {
      statusCode: 200,
      message: "Audit logs retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getStats = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const stats = await getAdminStats();

    sendSuccess(res, {
      statusCode: 200,
      message: "Admin statistics retrieved successfully",
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

export const getApplications = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const status = req.query.status as ApplicationStatus | undefined;
    const type = req.query.type as ApplicationType | undefined;

    if (status && !Object.values(ApplicationStatus).includes(status)) {
      return next(new AppError(`Invalid status filter: ${status}`, 400));
    }
    if (type && !Object.values(ApplicationType).includes(type)) {
      return next(new AppError(`Invalid type filter: ${type}`, 400));
    }

    const result = await listRoleApplications({ page, limit, status, type });

    sendSuccess(res, {
      statusCode: 200,
      message: "Role applications retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const approveApplication = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await approveRoleApplication(
      req.user.id,
      req.params.id as string
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Application approved and user role updated successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const rejectApplication = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { notes } = req.body;
    const result = await rejectRoleApplication(
      req.user.id,
      req.params.id as string,
      notes
    );

    sendSuccess(res, {
      statusCode: 200,
      message: "Application rejected successfully",
      data: { application: result },
    });
  } catch (error) {
    next(error);
  }
};

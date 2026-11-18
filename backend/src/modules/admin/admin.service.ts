import prisma from "../../config/db.ts";
import { Role } from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export interface ListUsersParams {
  page?: number;
  limit?: number;
  search?: string;
  role?: Role;
}

export const listUsers = async ({
  page = 1,
  limit = 20,
  search,
  role,
}: ListUsersParams) => {
  const skip = (page - 1) * limit;

  const where: Record<string, any> = {};
  if (role) {
    where.role = role;
  }
  if (search) {
    where.OR = [
      { email: { contains: search, mode: "insensitive" } },
      { profile: { fullName: { contains: search, mode: "insensitive" } } },
    ];
  }

  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: "desc" },
      include: {
        profile: { select: { fullName: true, imageUrl: true } },
        _count: { select: { pets: true } },
      },
    }),
    prisma.user.count({ where }),
  ]);

  return {
    users,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
};

export const getUserById = async (userId: string) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
      pets: {
        orderBy: { createdAt: "desc" },
        include: { images: true },
      },
    },
  });

  if (!user) {
    throw new AppError("User not found", 404);
  }

  return user;
};

export const updateUserRole = async (
  actorId: string,
  targetId: string,
  newRole: Role
) => {
  // Prevent self-demotion
  if (actorId === targetId) {
    throw new AppError("You cannot change your own role", 400);
  }

  const targetUser = await prisma.user.findUnique({
    where: { id: targetId },
  });

  if (!targetUser) {
    throw new AppError("Target user not found", 404);
  }

  const oldRole = targetUser.role;

  if (oldRole === newRole) {
    throw new AppError(`User already has role ${newRole}`, 400);
  }

  // Guard: cannot remove the last ADMIN
  if (oldRole === Role.ADMIN && newRole !== Role.ADMIN) {
    const adminCount = await prisma.user.count({
      where: { role: Role.ADMIN },
    });
    if (adminCount <= 1) {
      throw new AppError(
        "Cannot remove the last remaining ADMIN. Promote another user first.",
        400
      );
    }
  }

  // Validate the requested role
  if (!Object.values(Role).includes(newRole)) {
    throw new AppError(`Invalid role: ${newRole}`, 400);
  }

  const [updatedUser] = await prisma.$transaction([
    prisma.user.update({
      where: { id: targetId },
      data: { role: newRole },
      include: { profile: true },
    }),
    prisma.adminAuditLog.create({
      data: {
        actorId,
        targetId,
        action: "ROLE_CHANGE",
        oldValue: oldRole,
        newValue: newRole,
      },
    }),
  ]);

  return updatedUser;
};

export const updateUserStatus = async (
  actorId: string,
  targetId: string,
  isActive: boolean
) => {
  // Prevent self-deactivation
  if (actorId === targetId) {
    throw new AppError("You cannot deactivate your own account", 400);
  }

  const targetUser = await prisma.user.findUnique({
    where: { id: targetId },
  });

  if (!targetUser) {
    throw new AppError("Target user not found", 404);
  }

  if (targetUser.isActive === isActive) {
    throw new AppError(
      `User is already ${isActive ? "active" : "deactivated"}`,
      400
    );
  }

  const [updatedUser] = await prisma.$transaction([
    prisma.user.update({
      where: { id: targetId },
      data: { isActive },
      include: { profile: true },
    }),
    prisma.adminAuditLog.create({
      data: {
        actorId,
        targetId,
        action: isActive ? "REACTIVATE" : "DEACTIVATE",
        oldValue: String(!isActive),
        newValue: String(isActive),
      },
    }),
  ]);

  return updatedUser;
};

export const getAuditLogs = async (page = 1, limit = 50) => {
  const skip = (page - 1) * limit;

  const [logs, total] = await Promise.all([
    prisma.adminAuditLog.findMany({
      skip,
      take: limit,
      orderBy: { createdAt: "desc" },
      include: {
        actor: {
          select: { id: true, email: true, role: true },
        },
        target: {
          select: { id: true, email: true, role: true },
        },
      },
    }),
    prisma.adminAuditLog.count(),
  ]);

  return {
    logs,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
};

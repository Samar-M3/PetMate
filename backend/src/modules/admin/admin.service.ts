import prisma from "../../config/db.ts";
import {
  Role,
  ApplicationType,
  ApplicationStatus,
  MatchStatus,
} from "../../generated/prisma/client.ts";
import { AppError } from "../../middleware/errorHandler.ts";
import { endConversation } from "../../services/firestore.service.ts";
import { NotificationService } from "../../services/notification.service.ts";

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

  // If filtering for VETERINARIAN role, we need to merge users with VETERINARIAN role
  // and veterinarians from the Veterinarian table
  if (role === Role.VETERINARIAN) {
    const [vetUsers, veterinarians, vetUsersTotal, vetsTotal] = await Promise.all([
      prisma.user.findMany({
        where: { role: Role.VETERINARIAN, ...(search ? { OR: [
          { email: { contains: search, mode: "insensitive" } },
          { profile: { fullName: { contains: search, mode: "insensitive" } } },
        ]} : {}) },
        skip,
        take: limit,
        orderBy: { createdAt: "desc" },
        include: {
          profile: { select: { fullName: true, imageUrl: true } },
          _count: { select: { pets: true } },
        },
      }),
      prisma.veterinarian.findMany({
        where: search ? {
          OR: [
            { name: { contains: search, mode: "insensitive" } },
            { clinicName: { contains: search, mode: "insensitive" } },
          ]
        } : {},
        skip,
        take: limit,
        orderBy: { createdAt: "desc" },
      }),
      prisma.user.count({ 
        where: { 
          role: Role.VETERINARIAN, 
          ...(search ? { 
            OR: [
              { email: { contains: search, mode: "insensitive" } },
              { profile: { fullName: { contains: search, mode: "insensitive" } } },
            ]
          } : {}) 
        } 
      }),
      prisma.veterinarian.count({ 
        where: search ? {
          OR: [
            { name: { contains: search, mode: "insensitive" } },
            { clinicName: { contains: search, mode: "insensitive" } },
          ]
        } : {} 
      })
    ]);

    // Merge users and veterinarians, avoiding duplicates by checking if user already has VETERINARIAN role
    const vetUserEmails = new Set(vetUsers.map(u => u.email?.toLowerCase()).filter(Boolean));
    const vetUsersFromVetTable = veterinarians
      .filter(v => !vetUserEmails.has(v.name.toLowerCase())) // Simple dedup by name
      .map(v => ({
        id: `vet_${v.id}`, // Prefix to distinguish from real users
        firebaseUid: `vet_${v.id}`,
        email: null,
        phoneNumber: null,
        role: Role.VETERINARIAN,
        isActive: v.isAcceptingBookings,
        onboardingCompleted: false,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
        profile: {
          fullName: v.name,
          imageUrl: null,
        },
        _count: { pets: 0 },
        isVeterinarianRecord: true,
        veterinarianData: v,
      }));

    const mergedUsers = [...vetUsers, ...vetUsersFromVetTable];
    const total = vetUsersTotal + vetsTotal;

    return {
      users: mergedUsers,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  // For non-VETERINARIAN roles, use the standard query
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
      slotEntitlements: {
        orderBy: { createdAt: "desc" },
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

  // When deactivating, end all active matches involving the suspended user's pets
  if (!isActive) {
    try {
      const userPets = await prisma.pet.findMany({
        where: { userId: targetId },
        select: { id: true },
      });
      const petIds = userPets.map((p) => p.id);

      if (petIds.length > 0) {
        const activeMatches = await prisma.match.findMany({
          where: {
            status: MatchStatus.ACTIVE,
            OR: [{ petAId: { in: petIds } }, { petBId: { in: petIds } }],
          },
          select: { id: true },
        });

        if (activeMatches.length > 0) {
          await prisma.match.updateMany({
            where: { id: { in: activeMatches.map((m) => m.id) } },
            data: {
              status: MatchStatus.ENDED,
              endedAt: new Date(),
              endedBy: actorId,
            },
          });

          for (const m of activeMatches) {
            await endConversation(m.id, "ACCOUNT_SUSPENDED");
          }
        }
      }
    } catch (err) {
      console.error("[AdminService] Failed to end matches on user deactivation:", err);
    }
  }

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

export const getAdminStats = async () => {
  const [roleCounts, totalPets, pendingApplications, totalUsers, totalEvents, totalVeterinarians] =
    await Promise.all([
      prisma.user.groupBy({
        by: ["role"],
        _count: { _all: true },
      }),
      prisma.pet.count(),
      prisma.roleApplication.count({
        where: { status: "PENDING" },
      }),
      prisma.user.count(),
      prisma.event.count(),
      prisma.veterinarian.count(),
    ]);

  const usersByRole: Record<string, number> = {
    PET_OWNER: 0,
    SELLER: 0,
    VETERINARIAN: 0,
    ADMIN: 0,
  };

  for (const group of roleCounts) {
    usersByRole[group.role] = group._count._all;
  }

  return {
    totalUsers,
    usersByRole,
    totalPets,
    totalOrders: 0,
    pendingApplications,
    totalEvents,
    totalVeterinarians,
  };
};

export interface ListApplicationsParams {
  status?: ApplicationStatus;
  type?: ApplicationType;
  page?: number;
  limit?: number;
}

export const listRoleApplications = async ({
  status = "PENDING",
  type,
  page = 1,
  limit = 20,
}: ListApplicationsParams = {}) => {
  const skip = (page - 1) * limit;
  const where: any = {};
  if (status) where.status = status;
  if (type) where.type = type;

  const [applications, total] = await Promise.all([
    prisma.roleApplication.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: "desc" },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            phoneNumber: true,
            role: true,
            profile: {
              select: {
                fullName: true,
                imageUrl: true,
                location: true,
              },
            },
            store: true,
          },
        },
        reviewer: {
          select: {
            id: true,
            email: true,
            profile: { select: { fullName: true } },
          },
        },
      },
    }),
    prisma.roleApplication.count({ where }),
  ]);

  return {
    applications,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
};

export const approveRoleApplication = async (
  actorId: string,
  applicationId: string
) => {
  const application = await prisma.roleApplication.findUnique({
    where: { id: applicationId },
    include: { user: true },
  });

  if (!application) {
    throw new AppError("Application not found", 404);
  }

  if (application.status !== "PENDING") {
    throw new AppError(
      `Application is already ${application.status.toLowerCase()}`,
      400
    );
  }

  const targetRole =
    application.type === "SELLER" ? Role.SELLER : Role.VETERINARIAN;

  const [updatedApp, updatedUser] = await prisma.$transaction(async (tx) => {
    const app = await tx.roleApplication.update({
      where: { id: applicationId },
      data: {
        status: "APPROVED",
        reviewedBy: actorId,
        reviewedAt: new Date(),
      },
    });

    const usr = await tx.user.update({
      where: { id: application.userId },
      data: { role: targetRole },
      include: { profile: true },
    });

    if (application.type === "SELLER") {
      await tx.store.updateMany({
        where: { userId: application.userId },
        data: {
          status: "APPROVED",
          reviewedAt: new Date(),
          reviewedBy: actorId,
        },
      });
    }

    await tx.adminAuditLog.create({
      data: {
        actorId,
        targetId: application.userId,
        action: "APPROVE_APPLICATION",
        oldValue: `${application.user.role} (PENDING ${application.type})`,
        newValue: `${targetRole} (APPROVED)`,
      },
    });

    return [app, usr];
  });

  try {
    await NotificationService.notifyApplicationStatus(
      application.userId,
      application.type,
      true
    );
  } catch (err) {
    console.error("[AdminService] Failed to send application approved push:", err);
  }

  return { application: updatedApp, user: updatedUser };
};

export const rejectRoleApplication = async (
  actorId: string,
  applicationId: string,
  notes?: string
) => {
  const application = await prisma.roleApplication.findUnique({
    where: { id: applicationId },
  });

  if (!application) {
    throw new AppError("Application not found", 404);
  }

  if (application.status !== "PENDING") {
    throw new AppError(
      `Application is already ${application.status.toLowerCase()}`,
      400
    );
  }

  const updatedApp = await prisma.$transaction(async (tx) => {
    const app = await tx.roleApplication.update({
      where: { id: applicationId },
      data: {
        status: "REJECTED",
        notes: notes || application.notes,
        reviewedBy: actorId,
        reviewedAt: new Date(),
      },
    });

    if (application.type === "SELLER") {
      await tx.store.updateMany({
        where: { userId: application.userId },
        data: {
          status: "REJECTED",
          rejectionReason: notes || application.notes,
          reviewedAt: new Date(),
          reviewedBy: actorId,
        },
      });
    }

    await tx.adminAuditLog.create({
      data: {
        actorId,
        targetId: application.userId,
        action: "REJECT_APPLICATION",
        oldValue: "PENDING",
        newValue: `REJECTED${notes ? `: ${notes}` : ""}`,
      },
    });

    return app;
  });

  try {
    await NotificationService.notifyApplicationStatus(
      application.userId,
      application.type,
      false
    );
  } catch (err) {
    console.error("[AdminService] Failed to send application rejected push:", err);
  }

  return updatedApp;
};

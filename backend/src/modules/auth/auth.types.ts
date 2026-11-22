import type { Role, UserStatus } from "../../generated/prisma/enums.ts";

export interface RegisterDTO {
  email: string;
  password: string;
  fullName: string;
  phoneNumber?: string;
  role?: Role;
}

export interface LoginDTO {
  email: string;
  password: string;
}

export interface SafeUser {
  id: string;
  email: string;
  fullName: string;
  phoneNumber: string | null;
  role: Role;
  status: UserStatus;
  profileImage: string | null;
  address: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthResponse {
  user: SafeUser;
  token: string;
}

export interface JwtPayload {
  userId: string;
  email: string;
  role: Role;
}

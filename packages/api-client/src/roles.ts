import type { components } from "@shop/api-types";

export type Profile = components["schemas"]["UserProfile"];
export type Role = NonNullable<Profile["role"]>;

type Subject = Profile | null | undefined;

export const hasRole = (user: Subject, ...roles: Role[]) =>
  user?.role !== undefined && roles.includes(user.role);

export const isAdmin = (user: Subject) => hasRole(user, "admin");

export const isStaff = (user: Subject) => hasRole(user, "admin", "moderator");

export const isActivated = (user: Subject) => user?.active === true;

export const isVerified = (user: Subject) => user?.verified === true;

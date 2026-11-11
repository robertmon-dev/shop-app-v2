import { useCurrentUser } from "./actions/users";
import {
  hasRole,
  isActivated,
  isAdmin,
  isStaff,
  isVerified,
  type Role,
} from "./roles";
import { useSession } from "./session";

export const useAuth = () => {
  const { token, isAuthenticated } = useSession();
  const { data, isLoading } = useCurrentUser();
  const user = isAuthenticated ? (data?.data.user ?? null) : null;

  return {
    token,
    isAuthenticated,
    isLoading: isAuthenticated && isLoading,
    user,
    role: user?.role ?? null,
    isAdmin: isAdmin(user),
    isStaff: isStaff(user),
    isActivated: isActivated(user),
    isVerified: isVerified(user),
    hasRole: (...roles: Role[]) => hasRole(user, ...roles),
  };
};

import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const USERS = "/api/v1/users";

export const useUsers = () => useApi().$api.useQuery("get", "/api/v1/users");
export const useCurrentUser = () =>
  useApi().$api.useQuery("get", "/api/v1/users/me");

export const useUser = (id: number) =>
  useApi().$api.useQuery("get", "/api/v1/users/{id}", {
    params: { path: { id } },
  });

export const useUserActions = (id: number, page?: number) =>
  useApi().$api.useQuery("get", "/api/v1/users/{id}/actions", {
    params: { path: { id }, query: { page } },
  });

export const useRegister = () =>
  useApi().$api.useMutation("post", "/api/v1/users");
export const useLogout = () =>
  useApi().$api.useMutation("post", "/api/v1/users/logout");

export const useUpdateUser = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation("patch", "/api/v1/users/{id}", {
    onSuccess: invalidate,
  });
};

export const useDeleteUser = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation("delete", "/api/v1/users/{id}", {
    onSuccess: invalidate,
  });
};

export const useUpdateUserRole = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation("patch", "/api/v1/users/{id}/role/update", {
    onSuccess: invalidate,
  });
};

export const useUpdateUserDetails = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation(
    "patch",
    "/api/v1/users/{id}/update_details",
    { onSuccess: invalidate },
  );
};

export const useUpdateUserLocation = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation(
    "patch",
    "/api/v1/users/{id}/update_location",
    { onSuccess: invalidate },
  );
};

export const useUpdateEntrepreneurDetails = () => {
  const invalidate = useInvalidate(USERS);
  return useApi().$api.useMutation(
    "patch",
    "/api/v1/users/{id}/update_entrepreneur_details",
    {
      onSuccess: invalidate,
    },
  );
};

export const usersCovers = [
  "get /api/v1/users",
  "get /api/v1/users/me",
  "get /api/v1/users/{id}",
  "get /api/v1/users/{id}/actions",
  "post /api/v1/users",
  "post /api/v1/users/logout",
  "patch /api/v1/users/{id}",
  "delete /api/v1/users/{id}",
  "patch /api/v1/users/{id}/role/update",
  "patch /api/v1/users/{id}/update_details",
  "patch /api/v1/users/{id}/update_location",
  "patch /api/v1/users/{id}/update_entrepreneur_details",
] as const;

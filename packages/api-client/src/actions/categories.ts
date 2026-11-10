import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const CATEGORIES = "/api/v1/categories";

export const useCategories = () =>
  useApi().$api.useQuery("get", "/api/v1/categories");

export const useCreateCategory = () => {
  const invalidate = useInvalidate(CATEGORIES);
  return useApi().$api.useMutation("post", "/api/v1/categories", {
    onSuccess: invalidate,
  });
};

export const useUpdateCategory = () => {
  const invalidate = useInvalidate(CATEGORIES);
  return useApi().$api.useMutation("patch", "/api/v1/categories/{id}", {
    onSuccess: invalidate,
  });
};

export const useDeleteCategory = () => {
  const invalidate = useInvalidate(CATEGORIES);
  return useApi().$api.useMutation("delete", "/api/v1/categories/{id}", {
    onSuccess: invalidate,
  });
};

export const categoriesCovers = [
  "get /api/v1/categories",
  "post /api/v1/categories",
  "patch /api/v1/categories/{id}",
  "delete /api/v1/categories/{id}",
] as const;

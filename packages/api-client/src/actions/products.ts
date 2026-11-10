import { useMutation } from "@tanstack/react-query";

import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const PRODUCTS = "/api/v1/products";

export const useProducts = (page?: number) =>
  useApi().$api.useQuery("get", "/api/v1/products", {
    params: { query: { page } },
  });

export const useProduct = (id: string) =>
  useApi().$api.useQuery("get", "/api/v1/products/{id}", {
    params: { path: { id } },
  });

export const useCreateProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("post", "/api/v1/products", {
    onSuccess: invalidate,
  });
};

export const useUpdateProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("patch", "/api/v1/products/{id}", {
    onSuccess: invalidate,
  });
};

export const useDeleteProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("delete", "/api/v1/products/{id}", {
    onSuccess: invalidate,
  });
};

export const useLikeProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("post", "/api/v1/products/{id}/like", {
    onSuccess: invalidate,
  });
};

export const useRateProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("post", "/api/v1/products/{id}/rate", {
    onSuccess: invalidate,
  });
};

export const useCommentProduct = () => {
  const invalidate = useInvalidate(PRODUCTS);
  return useApi().$api.useMutation("post", "/api/v1/products/{id}/comment", {
    onSuccess: invalidate,
  });
};

export const useUploadProductPhoto = () => {
  const { fetchClient } = useApi();
  const invalidate = useInvalidate(PRODUCTS);

  return useMutation({
    mutationFn: async ({ id, image }: { id: string; image: Blob }) => {
      const { data } = await fetchClient.POST(
        "/api/v1/products/{id}/create_photo",
        {
          params: { path: { id } },
          body: { image: image as unknown as string },
          bodySerializer: () => {
            const form = new FormData();
            form.append("image", image);
            return form;
          },
        },
      );
      if (!data) throw new Error("Photo upload returned an empty response");
      return data;
    },
    onSuccess: invalidate,
  });
};

export const productsCovers = [
  "get /api/v1/products",
  "get /api/v1/products/{id}",
  "post /api/v1/products",
  "patch /api/v1/products/{id}",
  "delete /api/v1/products/{id}",
  "post /api/v1/products/{id}/like",
  "post /api/v1/products/{id}/rate",
  "post /api/v1/products/{id}/comment",
  "post /api/v1/products/{id}/create_photo",
] as const;

import type { ApiFailure } from "@shop/api-types";
import { useMutation } from "@tanstack/react-query";
import { useRef, useState } from "react";

import { ApiError } from "../errors";
import { useInvalidate } from "../invalidate";
import { nextPage } from "../pagination";
import { useApi } from "../provider";

const PRODUCTS = "/api/v1/products";

export const useProducts = (page?: number) =>
  useApi().$api.useQuery("get", "/api/v1/products", {
    params: { query: { page } },
  });

export const useInfiniteProducts = () =>
  useApi().$api.useInfiniteQuery(
    "get",
    "/api/v1/products",
    { params: { query: {} } },
    {
      pageParamName: "page",
      initialPageParam: 1,
      getNextPageParam: nextPage,
    },
  );

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
  const { baseUrl, getToken } = useApi();
  const invalidate = useInvalidate(PRODUCTS);
  const xhrRef = useRef<XMLHttpRequest | null>(null);
  const [progress, setProgress] = useState(0);

  const mutation = useMutation({
    mutationFn: ({ id, image }: { id: string; image: Blob }) =>
      new Promise<unknown>((resolve, reject) => {
        const form = new FormData();
        form.append("image", image);

        const xhr = new XMLHttpRequest();
        xhrRef.current = xhr;
        xhr.open("POST", `${baseUrl}/api/v1/products/${id}/create_photo`);

        const token = getToken?.();
        if (token) xhr.setRequestHeader("Authorization", `Bearer ${token}`);

        xhr.upload.onprogress = (event) => {
          if (event.lengthComputable) setProgress(event.loaded / event.total);
        };

        xhr.onload = () => {
          xhrRef.current = null;
          let body: unknown;
          try {
            body = xhr.responseText ? JSON.parse(xhr.responseText) : undefined;
          } catch {
            body = undefined;
          }
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve(body);
          } else {
            reject(
              new ApiError(xhr.status, body as Partial<ApiFailure> | undefined),
            );
          }
        };

        xhr.onerror = () => {
          xhrRef.current = null;
          reject(new ApiError(0, undefined));
        };

        xhr.onabort = () => {
          xhrRef.current = null;
          reject(new DOMException("Upload aborted", "AbortError"));
        };

        xhr.send(form);
      }),
    onSuccess: invalidate,
    onSettled: () => setProgress(0),
  });

  return { ...mutation, progress, abort: () => xhrRef.current?.abort() };
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

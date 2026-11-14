import type { ResponseBody } from "@shop/api-types";
import { useQueryClient } from "@tanstack/react-query";

import { useApi } from "../provider";

const CART = "/api/v1/cart";
const cartQueryKey = ["get", CART] as const;

export const useCart = () =>
  useApi().$api.useQuery("get", "/api/v1/cart", undefined, {
    staleTime: 30_000,
  });

type CartResponse = ResponseBody<"/api/v1/cart", "get", 200>;

const useApplyCart = () => {
  const queryClient = useQueryClient();
  return (body: CartResponse) => queryClient.setQueryData(cartQueryKey, body);
};

export const useAddToCart = () => {
  const applyCart = useApplyCart();
  return useApi().$api.useMutation("post", "/api/v1/cart/add/{product_id}", {
    onSuccess: applyCart,
  });
};

export const useRemoveFromCart = () => {
  const applyCart = useApplyCart();
  return useApi().$api.useMutation("delete", "/api/v1/cart/revoke/{item_id}", {
    onSuccess: applyCart,
  });
};

export const useClearCart = () => {
  const applyCart = useApplyCart();
  return useApi().$api.useMutation("delete", "/api/v1/cart/clear", {
    onSuccess: applyCart,
  });
};

export const cartCovers = [
  "get /api/v1/cart",
  "post /api/v1/cart/add/{product_id}",
  "delete /api/v1/cart/revoke/{item_id}",
  "delete /api/v1/cart/clear",
] as const;

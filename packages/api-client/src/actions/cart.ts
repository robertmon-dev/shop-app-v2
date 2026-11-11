import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const CART = "/api/v1/cart";

export const useCart = () => useApi().$api.useQuery("get", "/api/v1/cart");

export const useAddToCart = () => {
  const invalidate = useInvalidate(CART);
  return useApi().$api.useMutation("post", "/api/v1/cart/add/{product_id}", {
    onSuccess: invalidate,
  });
};

export const useRemoveFromCart = () => {
  const invalidate = useInvalidate(CART);
  return useApi().$api.useMutation("delete", "/api/v1/cart/revoke/{item_id}", {
    onSuccess: invalidate,
  });
};

export const useClearCart = () => {
  const invalidate = useInvalidate(CART);
  return useApi().$api.useMutation("delete", "/api/v1/cart/clear", {
    onSuccess: invalidate,
  });
};

export const cartCovers = [
  "get /api/v1/cart",
  "post /api/v1/cart/add/{product_id}",
  "delete /api/v1/cart/revoke/{item_id}",
  "delete /api/v1/cart/clear",
] as const;

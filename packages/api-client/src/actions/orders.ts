import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const ORDERS = "/api/v1/orders";

export const useOrders = () => useApi().$api.useQuery("get", "/api/v1/orders");
export const useMyOrders = () =>
  useApi().$api.useQuery("get", "/api/v1/orders/me");

export const useOrder = (id: number) =>
  useApi().$api.useQuery("get", "/api/v1/orders/{id}", {
    params: { path: { id } },
  });

export const useCreateOrder = () => {
  const invalidate = useInvalidate(ORDERS, "/api/v1/cart");
  return useApi().$api.useMutation("post", "/api/v1/orders", {
    onSuccess: invalidate,
  });
};

export const useUpdateOrder = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation("patch", "/api/v1/orders/{id}", {
    onSuccess: invalidate,
  });
};

export const useDeleteOrder = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation("delete", "/api/v1/orders/{id}", {
    onSuccess: invalidate,
  });
};

export const useCancelOrder = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation("post", "/api/v1/orders/{id}/cancel", {
    onSuccess: invalidate,
  });
};

export const useSetOrderStatus = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation("patch", "/api/v1/orders/{id}/status", {
    onSuccess: invalidate,
  });
};

export const useSetOrderPaymentStatus = () => {
  const invalidate = useInvalidate(ORDERS, "/api/v1/payments");
  return useApi().$api.useMutation(
    "patch",
    "/api/v1/orders/{id}/payment_status",
    { onSuccess: invalidate },
  );
};

export const useAddOrderProduct = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation("post", "/api/v1/orders/{id}/products", {
    onSuccess: invalidate,
  });
};

export const useRemoveOrderProduct = () => {
  const invalidate = useInvalidate(ORDERS);
  return useApi().$api.useMutation(
    "delete",
    "/api/v1/orders/{id}/products/{product_id}",
    { onSuccess: invalidate },
  );
};

export const ordersCovers = [
  "get /api/v1/orders",
  "get /api/v1/orders/me",
  "get /api/v1/orders/{id}",
  "post /api/v1/orders",
  "patch /api/v1/orders/{id}",
  "delete /api/v1/orders/{id}",
  "post /api/v1/orders/{id}/cancel",
  "patch /api/v1/orders/{id}/status",
  "patch /api/v1/orders/{id}/payment_status",
  "post /api/v1/orders/{id}/products",
  "delete /api/v1/orders/{id}/products/{product_id}",
] as const;

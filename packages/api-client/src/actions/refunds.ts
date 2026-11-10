import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

const REFUNDS = "/api/v1/refunds";
const refundScopes = [REFUNDS, "/api/v1/orders"];

export const useOrderRefunds = (orderId: number) =>
  useApi().$api.useQuery("get", "/api/v1/orders/{order_id}/refunds", {
    params: { path: { order_id: orderId } },
  });

export const useMyRefunds = () =>
  useApi().$api.useQuery("get", "/api/v1/refunds/me");

export const useRefund = (id: number) =>
  useApi().$api.useQuery("get", "/api/v1/refunds/{id}", {
    params: { path: { id } },
  });

export const useCreateRefund = () => {
  const invalidate = useInvalidate(...refundScopes);
  return useApi().$api.useMutation(
    "post",
    "/api/v1/orders/{order_id}/refunds",
    { onSuccess: invalidate },
  );
};

export const useUpdateRefund = () => {
  const invalidate = useInvalidate(...refundScopes);
  return useApi().$api.useMutation("patch", "/api/v1/refunds/{id}", {
    onSuccess: invalidate,
  });
};

export const useDeleteRefund = () => {
  const invalidate = useInvalidate(...refundScopes);
  return useApi().$api.useMutation("delete", "/api/v1/refunds/{id}", {
    onSuccess: invalidate,
  });
};

export const useCancelRefund = () => {
  const invalidate = useInvalidate(...refundScopes);
  return useApi().$api.useMutation("post", "/api/v1/refunds/{id}/cancel", {
    onSuccess: invalidate,
  });
};

export const useCompleteRefund = () => {
  const invalidate = useInvalidate(...refundScopes);
  return useApi().$api.useMutation("post", "/api/v1/refunds/{id}/complete", {
    onSuccess: invalidate,
  });
};

export const refundsCovers = [
  "get /api/v1/orders/{order_id}/refunds",
  "post /api/v1/orders/{order_id}/refunds",
  "get /api/v1/refunds/me",
  "get /api/v1/refunds/{id}",
  "patch /api/v1/refunds/{id}",
  "delete /api/v1/refunds/{id}",
  "post /api/v1/refunds/{id}/cancel",
  "post /api/v1/refunds/{id}/complete",
] as const;

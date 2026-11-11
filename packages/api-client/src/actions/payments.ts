import { useInvalidate } from "../invalidate";
import { useApi } from "../provider";

export const usePayments = () =>
  useApi().$api.useQuery("get", "/api/v1/payments");

export const usePayment = (id: number) =>
  useApi().$api.useQuery("get", "/api/v1/payments/{id}", {
    params: { path: { id } },
  });

export const useCreatePayment = () => {
  const invalidate = useInvalidate("/api/v1/payments", "/api/v1/orders");
  return useApi().$api.useMutation("post", "/api/v1/payments", {
    onSuccess: invalidate,
  });
};

export const paymentsCovers = [
  "get /api/v1/payments",
  "get /api/v1/payments/{id}",
  "post /api/v1/payments",
] as const;

import type { ResponseBody } from "@shop/api-types";

import { useInvalidate } from "../invalidate";
import { pollWhile } from "../polling";
import { useApi } from "../provider";

export const usePayments = () =>
  useApi().$api.useQuery("get", "/api/v1/payments");

type PaymentResponse = ResponseBody<"/api/v1/payments/{id}", "get", 200>;

// A fresh payment starts "unpaid" and only the Stripe webhook moves it on,
// so poll until it settles instead of making the caller refetch manually.
const paymentSettling = (body: PaymentResponse | undefined) =>
  body?.data?.payment?.status === "unpaid";

export const usePayment = (id: number) =>
  useApi().$api.useQuery(
    "get",
    "/api/v1/payments/{id}",
    { params: { path: { id } } },
    { refetchInterval: pollWhile(paymentSettling) },
  );

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

import { useApi } from "../provider";

export const useInvoices = (page?: number) =>
  useApi().$api.useQuery("get", "/api/v1/invoices", {
    params: { query: { page } },
  });

export const useMyInvoices = () =>
  useApi().$api.useQuery("get", "/api/v1/invoices/me");

export const useInvoice = (id: number) =>
  useApi().$api.useQuery("get", "/api/v1/invoices/{id}", {
    params: { path: { id } },
  });

export const useInvoiceDownload = (
  id: number,
  options?: { enabled?: boolean },
) =>
  useApi().$api.useQuery(
    "get",
    "/api/v1/invoices/{id}/download",
    { params: { path: { id } } },
    options,
  );

export const invoicesCovers = [
  "get /api/v1/invoices",
  "get /api/v1/invoices/me",
  "get /api/v1/invoices/{id}",
  "get /api/v1/invoices/{id}/download",
] as const;

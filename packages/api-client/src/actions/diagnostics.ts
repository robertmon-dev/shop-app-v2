import { useApi } from "../provider";

export const useHealth = () =>
  useApi().$api.useQuery("get", "/api/v1/diagnostics/health");
export const useReadiness = () =>
  useApi().$api.useQuery("get", "/api/v1/diagnostics/readiness");

export const diagnosticsCovers = [
  "get /api/v1/diagnostics/health",
  "get /api/v1/diagnostics/readiness",
] as const;

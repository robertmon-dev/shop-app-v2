import { useApi } from "../provider";
import { useSessionStore } from "../session";

const tokenOf = (body: unknown): string | undefined => {
  const data = (body as { data?: { token?: unknown } } | undefined)?.data;
  return typeof data?.token === "string" ? data.token : undefined;
};

export const useLogin = () => {
  const { setToken } = useSessionStore();
  return useApi().$api.useMutation("post", "/api/v1/auth/login", {
    onSuccess: (body) => {
      const token = tokenOf(body);
      if (token) setToken(token);
    },
  });
};

export const useVerifyTwoFactor = () => {
  const { setToken } = useSessionStore();
  return useApi().$api.useMutation("post", "/api/v1/auth/verify_2fa", {
    onSuccess: (body) => {
      const token = tokenOf(body);
      if (token) setToken(token);
    },
  });
};
export const useActivateAccount = () =>
  useApi().$api.useMutation("patch", "/api/v1/auth/activate");
export const useVerifyAccount = () =>
  useApi().$api.useMutation("patch", "/api/v1/auth/verify");
export const useRequestPasswordReset = () =>
  useApi().$api.useMutation("post", "/api/v1/auth/password/reset");
export const useConfirmPasswordReset = () =>
  useApi().$api.useMutation("patch", "/api/v1/auth/password/reset");
export const useResendTwoFactorCode = () =>
  useApi().$api.useMutation("post", "/api/v1/auth/request_2fa_code_resend");
export const useResendActivationCode = () =>
  useApi().$api.useMutation(
    "post",
    "/api/v1/auth/request_activation_code_resend",
  );
export const useResendVerificationCode = () =>
  useApi().$api.useMutation(
    "post",
    "/api/v1/auth/request_verification_code_resend",
  );
export const useResendResetCode = () =>
  useApi().$api.useMutation("post", "/api/v1/auth/request_reset_code_resend");

export const authCovers = [
  "post /api/v1/auth/login",
  "post /api/v1/auth/verify_2fa",
  "patch /api/v1/auth/activate",
  "patch /api/v1/auth/verify",
  "post /api/v1/auth/password/reset",
  "patch /api/v1/auth/password/reset",
  "post /api/v1/auth/request_2fa_code_resend",
  "post /api/v1/auth/request_activation_code_resend",
  "post /api/v1/auth/request_verification_code_resend",
  "post /api/v1/auth/request_reset_code_resend",
] as const;

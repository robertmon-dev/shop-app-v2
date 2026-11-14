import { useCallback, useState } from "react";

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

export type LoginFlowState =
  | { status: "idle" }
  | { status: "requiresTwoFactor"; mail: string; userId: number }
  | { status: "authenticated" };

export const useLoginFlow = () => {
  const [state, setState] = useState<LoginFlowState>({ status: "idle" });
  const login = useLogin();
  const verifyTwoFactor = useVerifyTwoFactor();

  const submit = useCallback(
    async (mail: string, password: string) => {
      const { data } = await login.mutateAsync({ body: { mail, password } });
      setState(
        "two_factor_required" in data
          ? { status: "requiresTwoFactor", mail, userId: data.user_id }
          : { status: "authenticated" },
      );
    },
    [login],
  );

  const verifyCode = useCallback(
    async (secondFactorCode: string) => {
      if (state.status !== "requiresTwoFactor") {
        throw new Error("No pending 2FA verification to submit a code for");
      }
      await verifyTwoFactor.mutateAsync({
        body: { mail: state.mail, second_factor_code: secondFactorCode },
      });
      setState({ status: "authenticated" });
    },
    [state, verifyTwoFactor],
  );

  const reset = useCallback(() => setState({ status: "idle" }), []);

  return {
    state,
    submit,
    verifyCode,
    reset,
    isPending: login.isPending || verifyTwoFactor.isPending,
    error: login.error ?? verifyTwoFactor.error,
  };
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

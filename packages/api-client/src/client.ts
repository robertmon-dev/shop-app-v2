import type { paths } from "@shop/api-types";
import createFetchClient, { type Middleware } from "openapi-fetch";
import createQueryClient from "openapi-react-query";

import { ApiError } from "./errors";
import { requestValidation, responseValidation } from "./validation";

export interface ApiClientOptions {
  baseUrl: string;
  getToken?: () => string | null | undefined;
  validate?: boolean;
  onUnauthorized?: () => void;
}

const authentication = (
  getToken: NonNullable<ApiClientOptions["getToken"]>,
): Middleware => ({
  onRequest({ request }) {
    const token = getToken();
    if (token) request.headers.set("Authorization", `Bearer ${token}`);
    return request;
  },
});

const failures = (onUnauthorized?: () => void): Middleware => ({
  async onResponse({ response }) {
    if (response.ok) return response;
    if (response.status === 401) onUnauthorized?.();

    const body = await response
      .clone()
      .json()
      .catch(() => undefined);
    throw new ApiError(response.status, body);
  },
});

export const createApiClient = ({
  baseUrl,
  getToken,
  validate = true,
  onUnauthorized,
}: ApiClientOptions) => {
  const fetchClient = createFetchClient<paths>({ baseUrl });
  if (getToken) fetchClient.use(authentication(getToken));
  if (validate) fetchClient.use(requestValidation, responseValidation);
  fetchClient.use(failures(onUnauthorized));

  return { fetchClient, $api: createQueryClient(fetchClient) };
};

export type ApiClient = ReturnType<typeof createApiClient>;

import createClient, { type ClientOptions } from "openapi-fetch";

import type { components, paths } from "./schema";

export type { components, paths };
export * from "./zod/zod.gen";
export { operationSchemas } from "./registry.gen";

type HttpMethod = "get" | "post" | "put" | "patch" | "delete";

type Operation<P extends keyof paths, M extends HttpMethod> =
  paths[P] extends Record<M, infer Op> ? Op : never;

type JsonBody<T> = T extends { content: { "application/json": infer B } }
  ? B
  : never;

export type RequestBody<P extends keyof paths, M extends HttpMethod> =
  Operation<P, M> extends { requestBody?: infer B }
    ? JsonBody<NonNullable<B>>
    : never;

export type ResponseBody<
  P extends keyof paths,
  M extends HttpMethod,
  Status extends number,
> =
  Operation<P, M> extends { responses: infer R }
    ? Status extends keyof R
      ? JsonBody<R[Status]>
      : never
    : never;

export interface ApiFailure {
  success: false;
  message: string;
  errors: string[];
}

export const createApiClient = (options: ClientOptions = {}) =>
  createClient<paths>(options);

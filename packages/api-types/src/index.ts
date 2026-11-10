import createClient, { type ClientOptions } from 'openapi-fetch';

import type { components, paths } from './schema';

export type { components, paths };

type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete';

type Operation<P extends keyof paths, M extends HttpMethod> = paths[P] extends Record<M, infer Op> ? Op : never;

type JsonBody<T> = T extends { content: { 'application/json': infer B } } ? B : never;

/** Body of a request, e.g. `RequestBody<'/api/v1/products', 'post'>`. */
export type RequestBody<P extends keyof paths, M extends HttpMethod> =
  Operation<P, M> extends { requestBody?: infer B } ? JsonBody<NonNullable<B>> : never;

/** Successful JSON response of an operation, e.g. `ResponseBody<'/api/v1/products', 'get', 200>`. */
export type ResponseBody<P extends keyof paths, M extends HttpMethod, Status extends number> =
  Operation<P, M> extends { responses: infer R }
    ? Status extends keyof R
      ? JsonBody<R[Status]>
      : never
    : never;

/** Failure envelope returned by every endpoint: `{ success: false, message, errors }`. */
export interface ApiFailure {
  success: false;
  message: string;
  errors: string[];
}

export const createApiClient = (options: ClientOptions = {}) => createClient<paths>(options);

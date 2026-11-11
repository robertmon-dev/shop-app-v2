import { operationSchemas } from "@shop/api-types";
import type { Middleware, MiddlewareCallbackParams } from "openapi-fetch";
import type { ZodType } from "zod";

import { ApiValidationError, type ValidationTarget } from "./errors";

type Schemas = { request: ZodType; response: ZodType | null };

const operationKey = (request: Request, schemaPath: string) =>
  `${request.method.toLowerCase()} ${schemaPath}`;

const schemasFor = (key: string): Schemas | undefined =>
  (operationSchemas as Record<string, Schemas>)[key];

const nonEmpty = (value: Record<string, unknown> | undefined) =>
  value && Object.keys(value).length > 0 ? value : undefined;

const readJson = async (message: Request | Response) => {
  const type = message.headers.get("content-type") ?? "";
  if (!type.includes("json")) return undefined;
  const text = await message.clone().text();
  return text ? JSON.parse(text) : undefined;
};

const check = (
  target: ValidationTarget,
  key: string,
  schema: ZodType,
  value: unknown,
) => {
  const result = schema.safeParse(value);
  if (!result.success)
    throw new ApiValidationError(target, key, result.error.issues);
};

const requestPayload = async (
  request: Request,
  params: MiddlewareCallbackParams["params"],
) => ({
  body: await readJson(request),
  path: nonEmpty(params.path),
  query: nonEmpty(params.query),
});

export const requestValidation: Middleware = {
  async onRequest({ request, schemaPath, params }) {
    const key = operationKey(request, schemaPath);
    const schemas = schemasFor(key);
    if (schemas)
      check(
        "request",
        key,
        schemas.request,
        await requestPayload(request, params),
      );
    return request;
  },
};

export const responseValidation: Middleware = {
  async onResponse({ request, response, schemaPath }) {
    if (!response.ok || response.status === 204) return response;
    const key = operationKey(request, schemaPath);
    const schema = schemasFor(key)?.response;
    if (schema) check("response", key, schema, await readJson(response));
    return response;
  },
};

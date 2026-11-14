import type { ApiFailure } from "@shop/api-types";
import type { core } from "zod";

export class ApiError extends Error {
  readonly status: number;
  readonly errors: string[];

  constructor(status: number, failure: Partial<ApiFailure> | undefined) {
    super(failure?.message ?? `Request failed with status ${status}`);
    this.name = "ApiError";
    this.status = status;
    this.errors = failure?.errors ?? [];
  }

  get isUnauthorized() {
    return this.status === 401;
  }

  get isForbidden() {
    return this.status === 403;
  }

  get isNotFound() {
    return this.status === 404;
  }

  get isConflict() {
    return this.status === 409;
  }

  get isUnprocessable() {
    return this.status === 422;
  }

  get isServerError() {
    return this.status >= 500;
  }

  /** Checks the failure message and errors for a known business-rule reason. */
  matches(pattern: string | RegExp): boolean {
    const test =
      typeof pattern === "string"
        ? (text: string) => text.toLowerCase().includes(pattern.toLowerCase())
        : (text: string) => pattern.test(text);
    return test(this.message) || this.errors.some(test);
  }
}

export const isApiError = (error: unknown): error is ApiError =>
  error instanceof ApiError;

export type ValidationTarget = "request" | "response";

export class ApiValidationError extends Error {
  readonly target: ValidationTarget;
  readonly operation: string;
  readonly issues: core.$ZodIssue[];

  constructor(
    target: ValidationTarget,
    operation: string,
    issues: core.$ZodIssue[],
  ) {
    super(`Invalid ${target} for ${operation}`);
    this.name = "ApiValidationError";
    this.target = target;
    this.operation = operation;
    this.issues = issues;
  }
}

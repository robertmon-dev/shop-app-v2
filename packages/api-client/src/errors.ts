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
}

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

import type { ApiFailure } from "@shop/api-types";

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

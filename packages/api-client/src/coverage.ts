import type { paths } from "@shop/api-types";

import { authCovers as auth } from "./actions/auth";
import { cartCovers as cart } from "./actions/cart";
import { categoriesCovers as categories } from "./actions/categories";
import { diagnosticsCovers as diagnostics } from "./actions/diagnostics";
import { invoicesCovers as invoices } from "./actions/invoices";
import { ordersCovers as orders } from "./actions/orders";
import { paymentsCovers as payments } from "./actions/payments";
import { productsCovers as products } from "./actions/products";
import { refundsCovers as refunds } from "./actions/refunds";
import { usersCovers as users } from "./actions/users";

type Method = "get" | "post" | "put" | "patch" | "delete";

type Operations = {
  [P in keyof paths]: {
    [M in Method]: [NonNullable<paths[P][M]>] extends [never]
      ? never
      : `${M} ${P}`;
  }[Method];
}[keyof paths];

type Excluded =
  | `put ${string}`
  | "get /api/v1/diagnostics/metrics"
  | "post /api/v1/n8n_webhook/handle"
  | "post /api/v1/stripe_payments_webhook/handle";

type Covered =
  | (typeof auth)[number]
  | (typeof cart)[number]
  | (typeof categories)[number]
  | (typeof diagnostics)[number]
  | (typeof invoices)[number]
  | (typeof orders)[number]
  | (typeof payments)[number]
  | (typeof products)[number]
  | (typeof refunds)[number]
  | (typeof users)[number];

type Missing = Exclude<Operations, Covered | Excluded>;

export const everyOperationHasAnAction: [Missing] extends [never]
  ? true
  : Missing = true;

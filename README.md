# Shop on Rails

Monorepo for the shop: a Rails API and the TypeScript packages that consume it.

- [Overview](#overview)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Make targets](#make-targets)
- [Yarn scripts](#yarn-scripts)
- [Environment variables](#environment-variables)
- [Architecture](#architecture)
- [Testing](#testing)
- [Addresses](#addresses)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Overview

- **API** (`apps/api`) — Rails 8 service for users, authorization, products, carts, orders, payments and refunds. Details in [apps/api/README.md](apps/api/README.md).
- **Typed contract** — the API's OpenAPI document is generated from the integration specs and turned into TypeScript types and Zod schemas (`@shop/api-types`).
- **Client** — `@shop/api-client` wraps those types in a TanStack Query client with auth, session and role helpers.
- **One entry point** — a root `Makefile` drives both sides; JavaScript is orchestrated by turbo.
- **Local infrastructure** — Postgres, Redis, RabbitMQ and Mailpit in Docker, with an optional three-node RabbitMQ cluster behind HAProxy.

---

## Repository layout

```
apps
├── api                    Rails 8 API (Ruby 3.4), see apps/api/README.md
└── web                    @shop/web  Vite + React + react-hook-form, uses the two packages below
    └── src
        ├── pages              route-level screens
        └── components         atoms, molecules, organisms, utility
packages
├── api-types              @shop/api-types  types and Zod schemas generated from swagger.yaml
└── api-client             @shop/api-client typed TanStack Query client for the API
docker
├── docker-compose.cluster.yml   3-node RabbitMQ cluster overlay
├── haproxy.cfg                  load balancer for the cluster
└── entrypoint.sh                cluster node entrypoint
docker-compose.yml         Postgres, Redis, RabbitMQ, Mailpit (+ the API itself behind the `app` profile)
Makefile                   Rails, Docker and workspace tasks
turbo.json                 task pipeline for the yarn workspaces
```

Ruby is managed by Bundler inside `apps/api`; everything JavaScript is a yarn workspace (`apps/*`, `packages/*`) orchestrated by turbo from the repository root.

---

## Prerequisites

- Ruby 3.4.5 (see `apps/api/.ruby-version`) and Bundler
- Node.js and Yarn 1.22 (`packageManager` in `package.json`)
- Docker Engine 20.10+ with the Compose plugin
- GNU Make

Postgres, Redis, RabbitMQ and an SMTP catcher all run in Docker; the host only needs Ruby and Node.

---

## Setup

```bash
git clone <repository>
cd shop-app-v2
make setup
make install
```

`make setup` copies `apps/api/.env.sample` to `apps/api/.env` if missing, installs gems, starts the containers, waits for them to become healthy and prepares both the development and test databases. `make install` installs the JavaScript workspaces.

Fill in the secrets in `apps/api/.env` afterwards (`RAILS_MASTER_KEY`, Stripe, Twilio). The file is gitignored.

```bash
make server   # http://localhost:3000
make test
yarn dev      # API and web (http://localhost:5173, /api proxied to :3000)
```

Host ports are deliberately non-default (Postgres `5433`, Redis `6380`, RabbitMQ `5673`) so the stack can run alongside other local projects. Change them in `apps/api/.env` if you prefer.

To run the application itself in Docker instead of on the host:

```bash
make docker-up
```

---

## Make targets

`make help` lists every target. Rails commands run from `apps/api`, so they work from the repository root. The ones used most:

| Target | What it does |
| --- | --- |
| `make setup` | Full bootstrap from a fresh clone |
| `make install` | `yarn install` for every workspace |
| `make up` / `make down` | Start / stop the infrastructure containers |
| `make reset` | Destroy containers **and volumes**, then rebuild |
| `make server` / `make jobs` / `make console` | Rails server, Solid Queue worker, Rails console |
| `make db-prepare` | Create and migrate development + test databases |
| `make db-reset` | Drop, recreate, migrate and seed |
| `make test` | Full RSpec suite |
| `make spec FILE=spec/models/user_spec.rb` | One file or example |
| `make lint` / `make lint-fix` | RuboCop |
| `make security` | Brakeman |
| `make swagger` | Regenerate `apps/api/swagger/v1/swagger.yaml` from the integration specs |
| `make types` | `swagger`, then regenerate `packages/api-types` |
| `make types-check` | Fail when the committed swagger or generated types are stale (CI) |
| `make cluster-up` | Three-node RabbitMQ cluster behind HAProxy |
| `make docker-up` | Whole stack, application included, in Docker |

---

## Yarn scripts

Run from the repository root; each one is a turbo task across all workspaces that define it.

| Script | What it does |
| --- | --- |
| `yarn build` | Build every workspace (dependencies first) |
| `yarn dev` | Start every `dev` task (Rails server and the Vite dev server for `@shop/web`) |
| `yarn lint` / `yarn lint:fix` | RuboCop for the API, `tsc --noEmit` for the packages |
| `yarn test` | RSpec for the API |
| `yarn clean` | Remove build output |

---

## Environment variables

`apps/api/.env.sample` is the canonical list, grouped by subsystem. Three files are involved:

| File | Tracked | Purpose |
| --- | --- | --- |
| `apps/api/.env.sample` | yes | Template and documentation |
| `apps/api/.env` | no | Local development values and secrets |
| `apps/api/.env.test` | yes | Test overrides — separate database, separate Redis logical db, dummy third-party keys |

Both the Makefile and `docker compose` read `apps/api/.env` for ports and credentials, so there is a single place to change them. See [apps/api/README.md](apps/api/README.md#environment-variables) for how the files are loaded.

---

## Architecture

```
Rails API ──► integration specs (rswag) ──► swagger.yaml ──► @shop/api-types ──► @shop/api-client
```

The OpenAPI document is the contract between the two sides:

1. Integration specs in `apps/api/spec/integration` describe every endpoint.
2. `make swagger` turns them into `apps/api/swagger/v1/swagger.yaml`.
3. `make types` feeds that file to `openapi-typescript` and `@hey-api/openapi-ts`, producing `schema.d.ts`, the Zod schemas and an operation registry in `packages/api-types`.
4. `apps/web` consumes both packages. `@shop/api-client` builds on those types: an `openapi-fetch` client, one module per resource under `src/actions`, plus `ApiProvider`, `SessionProvider`, `useAuth` and role helpers (`isAdmin`, `isStaff`, ...). `src/coverage.ts` makes the compiler complain when an endpoint has no client action.

Generated files are committed. After changing an endpoint, run `make types` and commit the result; `make types-check` enforces it.

Backend internals — services, controllers, the response envelope — are described in [apps/api/README.md](apps/api/README.md#architecture).

---

## Testing

| What | Command |
| --- | --- |
| API, full suite | `make test` (or `yarn test`) |
| API, one file or example | `make spec FILE=spec/services/carts/management_spec.rb:16` |
| API, by type | `make test-models`, `make test-services`, `make test-requests`, `make test-integration` |
| API, with coverage | `make coverage` |
| TypeScript packages | `yarn lint` (type-check) |
| Generated artefacts up to date | `make types-check` |

The layout of `spec/` and the testing rules are in [apps/api/README.md](apps/api/README.md#testing).

---

## Addresses

| What | Where |
| --- | --- |
| API | http://localhost:3000 |
| Web (Vite) | http://localhost:5173 |
| Swagger UI | http://localhost:3000/api_docs |
| Mailpit (captured mail) | http://localhost:8025 |
| RabbitMQ management | http://localhost:15673 |
| Prometheus metrics | http://localhost:3000/api/v1/diagnostics/metrics |

---

## Troubleshooting

- **Port already in use** — another project is holding 5432/6379. Change `POSTGRES_PORT` / `REDIS_PORT` in `apps/api/.env` and run `make restart`.
- **Database connection errors** — `make ps` to check health, `make wait` to block until ready.
- **`PendingMigrationError` in tests** — `make db-prepare`.
- **Credentials cannot be decrypted** — `RAILS_MASTER_KEY` is missing from `apps/api/.env`; `config/master.key` is not tracked.
- **`make types-check` fails** — the API changed without regenerating; run `make types` and commit `swagger.yaml` and the generated files.
- **Stale containers after changing compose** — `make reset` (this deletes the volumes).

---

## License

© 2025 Robert Moń, Kacper Majda. All rights reserved.
Free to use for non-commercial purposes.

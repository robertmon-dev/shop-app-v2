# Shop on Rails API

API service for users, authorization, products, carts, orders, payments and refunds.

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Make targets](#make-targets)
- [Environment variables](#environment-variables)
- [Architecture](#architecture)
- [Testing](#testing)
- [Addresses](#addresses)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Overview

- **User lifecycle** — registration, activation, verification, deletion.
- **Authorization** — JWT issuing and validation, two-factor authentication, password reset, token blacklisting (Redis with a database fallback).
- **Catalog and sales** — products, categories, cart, orders, payments (Stripe), refunds, invoices.
- **Roles** — `regular`, `moderator`, `admin`, enforced with CanCanCan.
- **Messaging** — RabbitMQ producer/consumer for order events; n8n webhooks for outbound integrations.
- **Observability** — Prometheus metrics and readiness/health probes under `/api/v1/diagnostics`.

---

## Prerequisites

- Ruby 3.4.5 (see `.ruby-version`)
- Bundler
- Docker Engine 20.10+ with the Compose plugin
- GNU Make

Postgres, Redis, RabbitMQ and an SMTP catcher all run in Docker; nothing but Ruby is needed on the host.

---

## Setup

```bash
git clone <repository>
cd shop-app
make setup
```

`make setup` copies `.env.sample` to `.env` if missing, installs gems, starts the containers, waits for them to become healthy and prepares both the development and test databases.

Fill in the secrets in `.env` afterwards (`RAILS_MASTER_KEY`, Stripe, Twilio). The file is gitignored.

```bash
make server   # http://localhost:3000
make test
```

Host ports are deliberately non-default (Postgres `5433`, Redis `6380`, RabbitMQ `5673`) so the stack can run alongside other local projects. Change them in `.env` if you prefer.

To run the application itself in Docker instead of on the host:

```bash
make docker-up
```

---

## Make targets

`make help` lists every target. The ones used most:

| Target | What it does |
| --- | --- |
| `make setup` | Full bootstrap from a fresh clone |
| `make up` / `make down` | Start / stop the infrastructure containers |
| `make reset` | Destroy containers **and volumes**, then rebuild |
| `make db-prepare` | Create and migrate development + test databases |
| `make db-reset` | Drop, recreate, migrate and seed |
| `make test` | Full RSpec suite |
| `make spec FILE=spec/models/user_spec.rb` | One file or example |
| `make lint` / `make lint-fix` | RuboCop |
| `make security` | Brakeman |
| `make swagger` | Regenerate `swagger/v1/swagger.yaml` from the integration specs |
| `make cluster-up` | Three-node RabbitMQ cluster behind HAProxy |

---

## Environment variables

`.env.sample` is the canonical list, grouped by subsystem. Three files are involved:

| File | Tracked | Purpose |
| --- | --- | --- |
| `.env.sample` | yes | Template and documentation |
| `.env` | no | Local development values and secrets |
| `.env.test` | yes | Test overrides — separate database, separate Redis logical db, dummy third-party keys |

dotenv loads `.env.test` before `.env` in the test environment, so test values win without duplicating secrets.

---

## Architecture

```
app
├── controllers/api            ApplicationController + Responding concern
│   └── v1                     one controller per resource, actions are one-liners
├── services/services          business logic, every call returns Services::Result
│   └── concerns               Handlers (error wrapping) + ResultHelpers (result factories)
├── observers                  rails-observers hooks for side effects
├── models
├── jobs                       Solid Queue jobs
└── views/api/v1               Jbuilder templates, one directory per controller
```

Controllers do three things: load/authorize the resource, call a service, hand the `Services::Result` to the responder. All rendering decisions live in `Api::Responding`:

```ruby
def index   = respond_with_view(:index, orders: accessible_orders)
def create  = respond_with(Services::OrderCreationService.call(**create_params))
def cancel  = respond_with(order_management_service.cancel)
def destroy = respond_with_destroy(order_management_service.destroy)
```

Services never render and never touch `params`; controllers never contain business rules.

---

## Testing

RSpec, with `spec/` laid out as:

| Directory | Type |
| --- | --- |
| `spec/models` | model unit specs |
| `spec/services` | service unit specs |
| `spec/controllers` | controller specs |
| `spec/requests` | end-to-end request specs |
| `spec/integration` | rswag specs that generate the OpenAPI document |

```bash
make test
make test-models
make test-services
make test-requests
make test-integration
make spec FILE=spec/services/cart_service_spec.rb:16
```

Controller specs must **not** call `routes.draw` unless they define an anonymous `controller do` block — on a named controller spec `routes` is the application route set and `draw` clears it, which breaks routing for every spec that runs afterwards in the same process.

---

## Addresses

| What | Where |
| --- | --- |
| API | http://localhost:3000 |
| Swagger UI | http://localhost:3000/api_docs |
| Mailpit (captured mail) | http://localhost:8025 |
| RabbitMQ management | http://localhost:15673 |
| Prometheus metrics | http://localhost:3000/api/v1/diagnostics/metrics |

---

## Troubleshooting

- **Port already in use** — another project is holding 5432/6379. Change `POSTGRES_PORT` / `REDIS_PORT` in `.env` and run `make restart`.
- **Database connection errors** — `make ps` to check health, `make wait` to block until ready.
- **`PendingMigrationError` in tests** — `make db-prepare`.
- **Credentials cannot be decrypted** — `RAILS_MASTER_KEY` is missing from `.env`; `config/master.key` is not tracked.
- **Stale containers after changing compose** — `make reset` (this deletes the volumes).

---

## License

© 2025 Robert Moń, Kacper Majda. All rights reserved.
Free to use for non-commercial purposes.

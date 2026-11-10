# Shop

Monorepo for the shop: a Rails API and, next to it, the TypeScript side.

```
apps/
  api/            Rails 8 API (Ruby 3.4) - see apps/api/README.md
  web/            TypeScript apps live here (yarn workspace)
packages/         shared TypeScript packages
docker/           infrastructure only: HAProxy config and the RabbitMQ cluster entrypoint
docker-compose.yml  Postgres, Redis, RabbitMQ, Mailpit (+ the API itself behind the `app` profile)
Makefile          one entry point for both sides
```

Ruby is managed by Bundler inside `apps/api`; everything JavaScript is a yarn workspace
(`apps/*`, `packages/*`) orchestrated by turbo from the repository root.

## Quick start

```bash
make setup      # apps/api/.env, gems, containers, databases
make server     # Rails API on :3000
make test       # RSpec
yarn install    # JavaScript workspaces (once apps/web or packages/* exist)
```

`make help` lists every target. The Makefile runs Rails commands from `apps/api`, so the
usual `make test`, `make lint`, `make db-migrate` keep working from the root; to run a single
spec use `make spec FILE=spec/services/carts/management_spec.rb`.

Configuration for the API lives in `apps/api/.env` (copied from `apps/api/.env.sample` by
`make setup`); `docker compose` reads the same file for ports and credentials.

Everything about the API itself - architecture, response envelope, environment variables,
testing - is in [apps/api/README.md](apps/api/README.md).

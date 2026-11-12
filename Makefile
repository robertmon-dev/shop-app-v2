SHELL := /bin/bash

API_DIR       = apps/api
API           = cd $(API_DIR) &&
COMPOSE       = docker compose $(if $(wildcard $(API_DIR)/.env),--env-file $(API_DIR)/.env)
CLUSTER_FILES = -f docker-compose.yml -f docker/docker-compose.cluster.yml
INFRA         = db redis rabbitmq mailpit
BUNDLE        = bundle exec
RAILS         = bin/rails
YARN          = yarn
TURBO         = yarn turbo

-include $(API_DIR)/.env

POSTGRES_USER            ?= postgres
POSTGRES_PASSWORD        ?= postgres
POSTGRES_PORT            ?= 5433
POSTGRES_DB              ?= shop_on_rails_development
REDIS_PORT               ?= 6380
MAILPIT_UI_PORT          ?= 8025
RABBITMQ_MANAGEMENT_PORT ?= 15673

CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m

.DEFAULT_GOAL := help

# ==============================================================================
# Utility
# ==============================================================================

.PHONY: help
help: ## Display this help message
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-30s$(RESET) %s\n", $$1, $$2}'

# ==============================================================================
# Setup & Maintenance
# ==============================================================================

.PHONY: setup
setup: ## Full project orchestration (.env -> gems -> infra -> DB setup)
	@echo "$(CYAN)=> Running full project setup...$(RESET)"
	@test -f $(API_DIR)/.env || (cp $(API_DIR)/.env.sample $(API_DIR)/.env && echo "$(YELLOW)=> Created $(API_DIR)/.env from .env.sample - fill in the secrets$(RESET)")
	@echo "$(CYAN)=> Installing gems...$(RESET)"
	@$(API) bundle install
	@$(MAKE) up
	@$(MAKE) db-prepare
	@echo "$(GREEN)=> Setup complete! Run 'make server' to start the API or 'make test' to run the suite.$(RESET)"

# ==============================================================================
# Infrastructure (Postgres, Redis, RabbitMQ, Mailpit)
# ==============================================================================

.PHONY: up
up: ## Start Postgres, Redis, RabbitMQ and Mailpit, then wait for health
	@echo "=> Starting local infrastructure..."
	@$(COMPOSE) up -d $(INFRA)
	@$(MAKE) wait
	@echo "=> Infrastructure is ready."

.PHONY: wait
wait: ## Block until Postgres and Redis accept connections
	@echo -n "=> Waiting for services"
	@for i in $$(seq 1 60); do \
		if $(COMPOSE) exec -T db pg_isready -U $(POSTGRES_USER) >/dev/null 2>&1 \
			&& $(COMPOSE) exec -T redis redis-cli ping >/dev/null 2>&1; then \
			echo " ok"; exit 0; \
		fi; \
		echo -n "."; sleep 1; \
	done; \
	echo " timed out"; $(COMPOSE) ps; exit 1

.PHONY: down
down: ## Stop and remove containers (volumes survive)
	@echo "=> Stopping infrastructure..."
	@$(COMPOSE) down --remove-orphans

.PHONY: stop
stop: ## Stop containers without removing them
	@echo "=> Stopping containers..."
	@$(COMPOSE) stop

.PHONY: restart
restart: down up ## Recreate the infrastructure containers

.PHONY: ps
ps: ## Show container status
	@$(COMPOSE) ps

.PHONY: logs
logs: ## Tail logs from all containers
	@$(COMPOSE) logs -f --tail=100

.PHONY: reset
reset: ## Destroy containers AND volumes, then rebuild from scratch
	@echo "$(YELLOW)=> Destroying containers and volumes...$(RESET)"
	@$(COMPOSE) down -v --remove-orphans
	@$(MAKE) up
	@$(MAKE) db-prepare
	@echo "=> Reset complete."

# ==============================================================================
# Cluster (3-node RabbitMQ behind HAProxy)
# ==============================================================================

.PHONY: cluster-up
cluster-up: ## Start the 3-node RabbitMQ cluster behind HAProxy instead of a single node
	@echo "=> Starting clustered stack..."
	@$(COMPOSE) $(CLUSTER_FILES) up -d db redis mailpit rabbitmq1 rabbitmq2 rabbitmq3 haproxy
	@echo "=> Cluster is up."

.PHONY: cluster-down
cluster-down: ## Tear down the clustered stack
	@echo "=> Stopping clustered stack..."
	@$(COMPOSE) $(CLUSTER_FILES) down --remove-orphans

# ==============================================================================
# Docker (Full Stack)
# ==============================================================================

.PHONY: docker-build
docker-build: ## Build the application image
	@echo "=> Building application image..."
	@$(COMPOSE) --profile app build
	@echo "=> Build complete."

.PHONY: docker-up
docker-up: ## Run the whole stack, application included, inside Docker
	@echo "=> Starting full Docker stack..."
	@$(COMPOSE) --profile app up -d
	@$(COMPOSE) --profile app ps

.PHONY: docker-down
docker-down: ## Stop the full in-Docker stack
	@echo "=> Stopping full Docker stack..."
	@$(COMPOSE) --profile app down --remove-orphans

# ==============================================================================
# Database
# ==============================================================================

.PHONY: db-prepare
db-prepare: ## Create and migrate both development and test databases
	@echo "=> Preparing development and test databases..."
	@$(API) $(RAILS) db:prepare
	@$(API) RAILS_ENV=test $(RAILS) db:prepare
	@echo "=> Databases ready."

.PHONY: db-create
db-create: ## Create the databases
	@echo "=> Creating databases..."
	@$(API) $(RAILS) db:create
	@$(API) RAILS_ENV=test $(RAILS) db:create

.PHONY: db-migrate
db-migrate: ## Run pending migrations against development and test
	@echo "=> Running migrations..."
	@$(API) $(RAILS) db:migrate
	@$(API) RAILS_ENV=test $(RAILS) db:migrate
	@echo "=> Migrations complete."

.PHONY: db-rollback
db-rollback: ## Roll back the last migration (STEP=n)
	@echo "=> Rolling back $(or $(STEP),1) migration(s)..."
	@$(API) $(RAILS) db:rollback STEP=$(or $(STEP),1)

.PHONY: db-seed
db-seed: ## Seed the development database
	@echo "=> Seeding database..."
	@$(API) $(RAILS) db:seed

.PHONY: db-reset
db-reset: ## Drop, recreate, migrate and seed the development database
	@echo "$(YELLOW)=> Resetting databases...$(RESET)"
	@$(API) $(RAILS) db:drop db:create db:migrate db:seed
	@$(API) RAILS_ENV=test $(RAILS) db:drop db:create db:schema:load
	@echo "=> Databases reset."

.PHONY: psql
psql: ## Open a psql shell on the development database
	@PGPASSWORD=$(POSTGRES_PASSWORD) psql -h localhost -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(POSTGRES_DB)

.PHONY: redis-cli
redis-cli: ## Open a redis-cli session
	@$(COMPOSE) exec redis redis-cli

.PHONY: rabbit-ui
rabbit-ui: ## Print the RabbitMQ management URL
	@echo "http://localhost:$(RABBITMQ_MANAGEMENT_PORT)"

.PHONY: mail-ui
mail-ui: ## Print the Mailpit URL
	@echo "http://localhost:$(MAILPIT_UI_PORT)"

# ==============================================================================
# Tests
# ==============================================================================

.PHONY: test
test: ## Run the full RSpec suite
	@echo "=> Running tests..."
	@$(API) $(BUNDLE) rspec

.PHONY: test-models
test-models: ## Run model specs
	@echo "=> Running model specs..."
	@$(API) $(BUNDLE) rspec spec/models

.PHONY: test-services
test-services: ## Run service specs
	@echo "=> Running service specs..."
	@$(API) $(BUNDLE) rspec spec/services

.PHONY: test-requests
test-requests: ## Run request specs
	@echo "=> Running request specs..."
	@$(API) $(BUNDLE) rspec spec/requests

.PHONY: test-integration
test-integration: ## Run rswag integration specs
	@echo "=> Running integration specs..."
	@$(API) $(BUNDLE) rspec spec/integration

.PHONY: spec
spec: ## Run one file or example: make spec FILE=spec/models/user_spec.rb
	@echo "=> Running $(FILE)..."
	@$(API) $(BUNDLE) rspec $(FILE)

.PHONY: coverage
coverage: ## Run the suite with SimpleCov enabled
	@echo "=> Running tests with coverage..."
	@$(API) COVERAGE=true $(BUNDLE) rspec

# ==============================================================================
# JavaScript workspaces
# ==============================================================================

.PHONY: install
install: ## Install JavaScript dependencies for every workspace
	@echo "=> Installing workspace dependencies..."
	@$(YARN) install
	@echo "=> Installation complete."

# ==============================================================================
# Quality
# ==============================================================================

.PHONY: lint
lint: ## Run RuboCop
	@echo "=> Running linter..."
	@$(API) $(BUNDLE) rubocop
	@echo "=> Lint complete."

.PHONY: lint-fix
lint-fix: ## Run RuboCop with safe autocorrection
	@echo "=> Running linter with autofix..."
	@$(API) $(BUNDLE) rubocop -A
	@echo "=> Lint fix complete."

.PHONY: security
security: ## Run Brakeman
	@echo "=> Running security scan..."
	@$(API) $(BUNDLE) brakeman -q --no-pager

.PHONY: swagger
swagger: ## Regenerate swagger/v1/swagger.yaml from the integration specs
	@echo "=> Generating swagger docs..."
	@$(API) $(BUNDLE) rake rswag:specs:swaggerize
	@echo "=> Swagger docs generated."

# ==============================================================================
# TypeScript types (generated from the Rails OpenAPI document)
# ==============================================================================

.PHONY: types
types: swagger ## Regenerate packages/api-types from the integration specs
	@echo "=> Generating TypeScript types..."
	@$(YARN) workspace @shop/api-types generate
	@echo "=> Types generated."

.PHONY: types-check
types-check: swagger ## Fail when the committed swagger.yaml is stale
	@git diff --exit-code -- $(API_DIR)/swagger \
		|| (echo "$(YELLOW)=> swagger.yaml is out of date. Run 'make swagger' and commit the result.$(RESET)"; exit 1)

# ==============================================================================
# Running the app
# ==============================================================================

.PHONY: server
server: ## Start the API server on PORT (default 3000)
	@echo "=> Starting API server..."
	@$(API) $(RAILS) server

.PHONY: jobs
jobs: ## Start the Solid Queue worker
	@echo "=> Starting Solid Queue worker..."
	@$(API) bin/jobs

.PHONY: console
console: ## Open the Rails console
	@$(API) $(RAILS) console

.PHONY: routes
routes: ## List routes
	@$(API) $(RAILS) routes

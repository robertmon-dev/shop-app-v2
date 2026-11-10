SHELL := /bin/bash

COMPOSE       = docker compose
CLUSTER_FILES = -f docker-compose.yml -f docker/docker-compose.cluster.yml
INFRA         = db redis rabbitmq mailpit
BUNDLE        = bundle exec
RAILS         = bin/rails

-include .env

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
	@test -f .env || (cp .env.sample .env && echo "$(YELLOW)=> Created .env from .env.sample - fill in the secrets$(RESET)")
	@echo "$(CYAN)=> Installing gems...$(RESET)"
	@bundle install
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
	@$(RAILS) db:prepare
	@RAILS_ENV=test $(RAILS) db:prepare
	@echo "=> Databases ready."

.PHONY: db-create
db-create: ## Create the databases
	@echo "=> Creating databases..."
	@$(RAILS) db:create
	@RAILS_ENV=test $(RAILS) db:create

.PHONY: db-migrate
db-migrate: ## Run pending migrations against development and test
	@echo "=> Running migrations..."
	@$(RAILS) db:migrate
	@RAILS_ENV=test $(RAILS) db:migrate
	@echo "=> Migrations complete."

.PHONY: db-rollback
db-rollback: ## Roll back the last migration (STEP=n)
	@echo "=> Rolling back $(or $(STEP),1) migration(s)..."
	@$(RAILS) db:rollback STEP=$(or $(STEP),1)

.PHONY: db-seed
db-seed: ## Seed the development database
	@echo "=> Seeding database..."
	@$(RAILS) db:seed

.PHONY: db-reset
db-reset: ## Drop, recreate, migrate and seed the development database
	@echo "$(YELLOW)=> Resetting databases...$(RESET)"
	@$(RAILS) db:drop db:create db:migrate db:seed
	@RAILS_ENV=test $(RAILS) db:drop db:create db:schema:load
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
	@$(BUNDLE) rspec

.PHONY: test-models
test-models: ## Run model specs
	@echo "=> Running model specs..."
	@$(BUNDLE) rspec spec/models

.PHONY: test-services
test-services: ## Run service specs
	@echo "=> Running service specs..."
	@$(BUNDLE) rspec spec/services

.PHONY: test-requests
test-requests: ## Run request specs
	@echo "=> Running request specs..."
	@$(BUNDLE) rspec spec/requests

.PHONY: test-integration
test-integration: ## Run rswag integration specs
	@echo "=> Running integration specs..."
	@$(BUNDLE) rspec spec/integration

.PHONY: spec
spec: ## Run one file or example: make spec FILE=spec/models/user_spec.rb
	@echo "=> Running $(FILE)..."
	@$(BUNDLE) rspec $(FILE)

.PHONY: coverage
coverage: ## Run the suite with SimpleCov enabled
	@echo "=> Running tests with coverage..."
	@COVERAGE=true $(BUNDLE) rspec

# ==============================================================================
# Quality
# ==============================================================================

.PHONY: lint
lint: ## Run RuboCop
	@echo "=> Running linter..."
	@$(BUNDLE) rubocop
	@echo "=> Lint complete."

.PHONY: lint-fix
lint-fix: ## Run RuboCop with safe autocorrection
	@echo "=> Running linter with autofix..."
	@$(BUNDLE) rubocop -A
	@echo "=> Lint fix complete."

.PHONY: security
security: ## Run Brakeman
	@echo "=> Running security scan..."
	@$(BUNDLE) brakeman -q --no-pager

.PHONY: swagger
swagger: ## Regenerate swagger/v1/swagger.yaml from the integration specs
	@echo "=> Generating swagger docs..."
	@$(BUNDLE) rake rswag:specs:swaggerize
	@echo "=> Swagger docs generated."

# ==============================================================================
# Running the app
# ==============================================================================

.PHONY: server
server: ## Start the API server on PORT (default 3000)
	@echo "=> Starting API server..."
	@$(RAILS) server

.PHONY: jobs
jobs: ## Start the Solid Queue worker
	@echo "=> Starting Solid Queue worker..."
	@bin/jobs

.PHONY: console
console: ## Open the Rails console
	@$(RAILS) console

.PHONY: routes
routes: ## List routes
	@$(RAILS) routes

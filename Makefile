SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE        := docker compose
CLUSTER_FILES  := -f docker-compose.yml -f docker/docker-compose.cluster.yml
INFRA          := db redis rabbitmq mailpit

-include .env

POSTGRES_USER      ?= postgres
POSTGRES_PASSWORD  ?= postgres
POSTGRES_PORT      ?= 5433
POSTGRES_DB        ?= shop_on_rails_development
REDIS_PORT         ?= 6380
MAILPIT_UI_PORT    ?= 8025
RABBITMQ_MANAGEMENT_PORT ?= 15673

.PHONY: help setup up down stop restart ps logs wait reset \
        db-prepare db-create db-migrate db-rollback db-seed db-reset \
        test test-models test-services test-requests test-integration spec coverage \
        lint lint-fix security swagger \
        console server jobs routes psql redis-cli rabbit-ui mail-ui \
        cluster-up cluster-down docker-build docker-up docker-down

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ----- bootstrap -----

setup: ## One-shot bootstrap: .env, gems, containers, databases
	@test -f .env || (cp .env.sample .env && echo "Created .env from .env.sample - fill in the secrets")
	bundle install
	$(MAKE) up
	$(MAKE) db-prepare
	@echo "Ready. 'make server' to run the API, 'make test' to run the suite."

# ----- infrastructure -----

up: ## Start Postgres, Redis, RabbitMQ and Mailpit, then wait for health
	$(COMPOSE) up -d $(INFRA)
	$(MAKE) wait

wait: ## Block until Postgres and Redis accept connections
	@echo -n "Waiting for services"
	@for i in $$(seq 1 60); do \
		if $(COMPOSE) exec -T db pg_isready -U $(POSTGRES_USER) >/dev/null 2>&1 \
			&& $(COMPOSE) exec -T redis redis-cli ping >/dev/null 2>&1; then \
			echo " ok"; exit 0; \
		fi; \
		echo -n "."; sleep 1; \
	done; \
	echo " timed out"; $(COMPOSE) ps; exit 1

down: ## Stop and remove containers (volumes survive)
	$(COMPOSE) down --remove-orphans

stop: ## Stop containers without removing them
	$(COMPOSE) stop

restart: down up ## Recreate the infrastructure containers

ps: ## Show container status
	$(COMPOSE) ps

logs: ## Tail logs from all containers
	$(COMPOSE) logs -f --tail=100

reset: ## Destroy containers AND volumes, then rebuild from scratch
	$(COMPOSE) down -v --remove-orphans
	$(MAKE) up
	$(MAKE) db-prepare

cluster-up: ## Start the 3-node RabbitMQ cluster behind HAProxy instead of a single node
	$(COMPOSE) $(CLUSTER_FILES) up -d db redis mailpit rabbitmq1 rabbitmq2 rabbitmq3 haproxy

cluster-down: ## Tear down the clustered stack
	$(COMPOSE) $(CLUSTER_FILES) down --remove-orphans

docker-build: ## Build the application image
	$(COMPOSE) --profile app build

docker-up: ## Run the whole stack, application included, inside Docker
	$(COMPOSE) --profile app up -d
	$(COMPOSE) --profile app ps

docker-down: ## Stop the full in-Docker stack
	$(COMPOSE) --profile app down --remove-orphans

# ----- database -----

db-prepare: ## Create and migrate both development and test databases
	bin/rails db:prepare
	RAILS_ENV=test bin/rails db:prepare

db-create: ## Create the databases
	bin/rails db:create
	RAILS_ENV=test bin/rails db:create

db-migrate: ## Run pending migrations against development and test
	bin/rails db:migrate
	RAILS_ENV=test bin/rails db:migrate

db-rollback: ## Roll back the last migration (STEP=n)
	bin/rails db:rollback STEP=$(or $(STEP),1)

db-seed: ## Seed the development database
	bin/rails db:seed

db-reset: ## Drop, recreate, migrate and seed the development database
	bin/rails db:drop db:create db:migrate db:seed
	RAILS_ENV=test bin/rails db:drop db:create db:schema:load

psql: ## Open a psql shell on the development database
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -h localhost -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(POSTGRES_DB)

redis-cli: ## Open a redis-cli session
	$(COMPOSE) exec redis redis-cli

rabbit-ui: ## Print the RabbitMQ management URL
	@echo "http://localhost:$(RABBITMQ_MANAGEMENT_PORT)"

mail-ui: ## Print the Mailpit URL
	@echo "http://localhost:$(MAILPIT_UI_PORT)"

# ----- tests -----

test: ## Run the full RSpec suite
	bundle exec rspec

test-models: ## Run model specs
	bundle exec rspec spec/models

test-services: ## Run service specs
	bundle exec rspec spec/services

test-requests: ## Run request specs
	bundle exec rspec spec/requests

test-integration: ## Run rswag integration specs
	bundle exec rspec spec/integration

spec: ## Run one file or example: make spec FILE=spec/models/user_spec.rb
	bundle exec rspec $(FILE)

coverage: ## Run the suite with SimpleCov enabled
	COVERAGE=true bundle exec rspec

# ----- quality -----

lint: ## Run RuboCop
	bundle exec rubocop

lint-fix: ## Run RuboCop with safe autocorrection
	bundle exec rubocop -A

security: ## Run Brakeman
	bundle exec brakeman -q --no-pager

swagger: ## Regenerate swagger/v1/swagger.yaml from the integration specs
	bundle exec rake rswag:specs:swaggerize

# ----- running the app -----

server: ## Start the API server on $$PORT (default 3000)
	bin/rails server

jobs: ## Start the Solid Queue worker
	bin/jobs

console: ## Open the Rails console
	bin/rails console

routes: ## List routes
	bin/rails routes

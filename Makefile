BIN_DIR ?= bin
COMPOSE ?= docker compose
ENV_FILE ?= .env

.PHONY: build collector calculator fmt env-up env-down db-shell logs

build: collector calculator

collector:
	go build -o $(BIN_DIR)/collector ./cmd/collector

calculator:
	go build -o $(BIN_DIR)/calculator ./cmd/calculator

fmt:
	gofmt -w ./cmd ./internal

env-up:
	$(COMPOSE) --env-file $(ENV_FILE) up -d postgres

env-down:
	$(COMPOSE) --env-file $(ENV_FILE) down

db-shell:
	$(COMPOSE) exec postgres psql -U postgres -d costcompass

logs:
	$(COMPOSE) logs -f

# =============================================================================
# llama-swap (lif fork) — convenience wrappers around docker compose
#
# Override defaults via env or `make VAR=value`:
#   CONFIG=config-bee.yaml make up   # switch backend without editing .env
#   HOST_PORT=9000 make smoke        # if you've remapped the port
# =============================================================================
SHELL := bash
.DEFAULT_GOAL := help
.PHONY: help build up down restart logs smoke argv pins

CONFIG    ?=
HOST_PORT ?= 8020

help:  ## Show this help
	@grep -hE '^[a-z%-]+:.*##' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*##[[:space:]]*"} {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build:  ## Build the llama-swap:custom-cuda image
	docker compose build

up:  ## Start the container (pass CONFIG=config-X.yaml to override LLAMA_CONFIG)
	$(if $(CONFIG),LLAMA_CONFIG=$(CONFIG) )docker compose up -d

down:  ## Stop and remove the container
	docker compose down

restart:  ## Restart container (picks up config-*.yaml edits, no rebuild needed)
	docker compose restart

logs:  ## Tail container logs
	docker compose logs -f --tail=100

smoke:  ## Curl /v1/models and print model IDs (one per line)
	@curl -fsS http://localhost:$(HOST_PORT)/v1/models \
		| python3 -c 'import json,sys; [print(m["id"]) for m in json.load(sys.stdin)["data"]]'

argv:  ## Show argv of the running upstream llama-server (verifies macro expansion)
	@docker exec llama-swap ps -ef \
		| grep -E '/llama-server' \
		| grep -v grep \
		|| echo "(no upstream loaded — hit any model via /v1/chat/completions first)"

pins:  ## Show pinned-in-Dockerfile vs current local/remote image refs
	@echo "=== Pinned in Dockerfile ==="
	@grep '^FROM' Dockerfile | sed 's/^/  /'
	@echo
	@echo "=== Current local IDs (floating :server-cuda tag) ==="
	@for img in atomic-llama-cpp:server-cuda ik-llama-cpp:server-cuda beellama:server-cuda; do \
		printf "  %-32s %s\n" "$$img" "$$(docker inspect --format='{{.Id}}' $$img 2>/dev/null || echo MISSING)"; \
	done
	@echo
	@echo "=== Upstream registry digest (ghcr.io/mostlygeek/llama-swap:unified-cuda) ==="
	@docker images --digests ghcr.io/mostlygeek/llama-swap:unified-cuda \
		--format '  {{.Repository}}:{{.Tag}}  {{.Digest}}' 2>/dev/null \
		|| echo "  (not pulled)"

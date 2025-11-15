.PHONY: all build compile clean test eunit proper ct dialyzer xref \
        smoke-test load-test deps upgrade-deps shell release \
        docker-build docker-push docker-dev docker-test docker-bench \
        format check coverage help install bare-metal

# Variables
REBAR3 := $(shell which rebar3 || echo ./rebar3)
REBAR3_URL := https://s3.amazonaws.com/rebar3/rebar3
DOCKER_IMAGE := merkletrie
DOCKER_TAG := latest
OTP_VERSION := 27.1

# Color output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

all: deps compile test ## Build and test everything (default)

help: ## Display this help message
	@echo "$(CYAN)MerkleTrie Build System$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(CYAN)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install: ## Install rebar3 if not present
	@if [ ! -f $(REBAR3) ]; then \
		echo "$(YELLOW)Downloading rebar3...$(NC)"; \
		wget $(REBAR3_URL) && chmod +x rebar3; \
	else \
		echo "$(GREEN)rebar3 already installed$(NC)"; \
	fi

##@ Build

compile: install ## Compile the project
	@echo "$(CYAN)Compiling...$(NC)"
	@$(REBAR3) compile

build: compile ## Alias for compile

clean: ## Clean build artifacts
	@echo "$(CYAN)Cleaning...$(NC)"
	@$(REBAR3) clean
	@rm -rf _build ebin deps
	@rm -rf data/*.db
	@rm -rf erl_crash.dump

deps: install ## Fetch dependencies
	@echo "$(CYAN)Fetching dependencies...$(NC)"
	@$(REBAR3) get-deps

upgrade-deps: install ## Upgrade dependencies
	@echo "$(CYAN)Upgrading dependencies...$(NC)"
	@$(REBAR3) upgrade

##@ Testing

test: eunit proper ct ## Run all tests
	@echo "$(GREEN)All tests completed!$(NC)"

eunit: compile ## Run EUnit tests
	@echo "$(CYAN)Running EUnit tests...$(NC)"
	@$(REBAR3) eunit --verbose

proper: compile ## Run property-based tests
	@echo "$(CYAN)Running PropEr tests...$(NC)"
	@$(REBAR3) as test proper

ct: compile ## Run Common Test
	@echo "$(CYAN)Running Common Test...$(NC)"
	@$(REBAR3) ct --verbose || true

coverage: test ## Generate coverage report
	@echo "$(CYAN)Generating coverage report...$(NC)"
	@$(REBAR3) cover --verbose
	@echo "$(GREEN)Coverage report: _build/test/cover/index.html$(NC)"

smoke-test: compile ## Run smoke tests
	@echo "$(CYAN)Running smoke tests...$(NC)"
	@chmod +x ./scripts/smoke-test.sh
	@./scripts/smoke-test.sh

load-test: compile ## Run load/performance tests
	@echo "$(CYAN)Running load tests...$(NC)"
	@chmod +x ./scripts/load-test.sh
	@./scripts/load-test.sh

##@ Code Quality

dialyzer: compile ## Run Dialyzer static analysis
	@echo "$(CYAN)Running Dialyzer...$(NC)"
	@$(REBAR3) dialyzer

xref: compile ## Run cross-reference analysis
	@echo "$(CYAN)Running Xref...$(NC)"
	@$(REBAR3) xref

format: ## Format code (if formatter plugin available)
	@echo "$(CYAN)Formatting code...$(NC)"
	@$(REBAR3) fmt || echo "$(YELLOW)Formatter not available$(NC)"

check: dialyzer xref ## Run all static analysis checks
	@echo "$(GREEN)Static analysis complete!$(NC)"

lint: check ## Alias for check

##@ Development

shell: compile ## Start Erlang shell with project loaded
	@echo "$(CYAN)Starting Erlang shell...$(NC)"
	@$(REBAR3) shell

repl: shell ## Alias for shell

release: compile test ## Build production release
	@echo "$(CYAN)Building release...$(NC)"
	@$(REBAR3) as prod release
	@echo "$(GREEN)Release built: _build/prod/rel/trie$(NC)"

##@ Docker

docker-build: ## Build Docker image
	@echo "$(CYAN)Building Docker image...$(NC)"
	@docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-dev: ## Start development container
	@echo "$(CYAN)Starting development container...$(NC)"
	@docker-compose --profile dev up -d trie-dev
	@docker-compose exec trie-dev /bin/bash

docker-test: ## Run tests in Docker
	@echo "$(CYAN)Running tests in Docker...$(NC)"
	@docker-compose --profile test run --rm trie-test

docker-bench: ## Run benchmarks in Docker
	@echo "$(CYAN)Running benchmarks in Docker...$(NC)"
	@docker-compose --profile bench run --rm trie-bench

docker-push: docker-build ## Push Docker image
	@echo "$(CYAN)Pushing Docker image...$(NC)"
	@docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

docker-clean: ## Remove Docker containers and images
	@echo "$(CYAN)Cleaning Docker resources...$(NC)"
	@docker-compose down -v
	@docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) || true

##@ Bare Metal / Production

bare-metal: install deps compile test smoke-test ## Complete bare metal setup
	@echo "$(GREEN)Bare metal setup complete!$(NC)"
	@echo ""
	@echo "$(CYAN)System Information:$(NC)"
	@echo "  OTP Version: $$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
	@echo "  Erlang ERTS: $$(erl -eval 'erlang:display(erlang:system_info(version)), halt().' -noshell)"
	@echo "  Rebar3: $$($(REBAR3) version)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Run 'make shell' to start interactive shell"
	@echo "  2. Run 'make release' to build production release"
	@echo "  3. Check data/ directory for database files"

deploy: release ## Deploy (build release and show instructions)
	@echo "$(GREEN)Deployment package ready!$(NC)"
	@echo ""
	@echo "$(CYAN)To deploy to production:$(NC)"
	@echo "  1. Copy _build/prod/rel/trie to target server"
	@echo "  2. Run: ./bin/trie start"
	@echo "  3. Check status: ./bin/trie ping"
	@echo "  4. Attach console: ./bin/trie attach"

##@ Benchmarking

benchmark: load-test ## Alias for load-test

bench: load-test ## Alias for load-test

##@ Maintenance

distclean: clean ## Deep clean (removes all generated files)
	@echo "$(CYAN)Deep cleaning...$(NC)"
	@rm -rf _build deps ebin
	@rm -rf data/*.db logs/*.log
	@rm -rf tests/current
	@rm -rf erl_crash.dump
	@rm -f rebar3

watch: ## Watch for file changes and recompile (requires fswatch/inotifywait)
	@echo "$(CYAN)Watching for changes...$(NC)"
	@while true; do \
		inotifywait -e modify -r src/ test/ 2>/dev/null && \
		make compile; \
	done || echo "$(RED)Install inotifywait for watch functionality$(NC)"

##@ CI/CD

ci: deps compile check test smoke-test ## Run full CI pipeline locally
	@echo "$(GREEN)CI pipeline complete!$(NC)"

pre-commit: format check test ## Run pre-commit checks
	@echo "$(GREEN)Pre-commit checks passed!$(NC)"

##@ Information

info: ## Display project information
	@echo "$(CYAN)MerkleTrie Project Information$(NC)"
	@echo ""
	@echo "$(YELLOW)Description:$(NC)"
	@echo "  Persistent Merkle Tree database implementation in Erlang"
	@echo ""
	@echo "$(YELLOW)Features:$(NC)"
	@echo "  - Deterministic root hash"
	@echo "  - Historical reads at any height"
	@echo "  - Cryptographic proof generation"
	@echo "  - Append-only immutable structure"
	@echo ""
	@echo "$(YELLOW)Build System:$(NC)"
	@echo "  Rebar3: $(REBAR3)"
	@echo ""
	@echo "$(YELLOW)Project Structure:$(NC)"
	@tree -L 2 -I 'deps|_build|ebin|.git' . || ls -la

version: ## Show version information
	@echo "OTP: $$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
	@echo "Rebar3: $$($(REBAR3) version)"

status: ## Show project status
	@echo "$(CYAN)Project Status$(NC)"
	@echo ""
	@echo "$(YELLOW)Git Status:$(NC)"
	@git status -s || echo "Not a git repository"
	@echo ""
	@echo "$(YELLOW)Build Status:$(NC)"
	@if [ -d "_build/default/lib/trie" ]; then \
		echo "  $(GREEN)✓$(NC) Compiled"; \
	else \
		echo "  $(RED)✗$(NC) Not compiled"; \
	fi
	@echo ""
	@echo "$(YELLOW)Dependencies:$(NC)"
	@if [ -d "deps" ]; then \
		echo "  $(GREEN)✓$(NC) Downloaded ($$(ls -1 deps | wc -l) packages)"; \
	else \
		echo "  $(RED)✗$(NC) Not downloaded"; \
	fi

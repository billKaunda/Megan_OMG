# ---------------------------------------------------------------------------
# Makefile — Foundry workflow for the smart contract suite.
#
# This is the entry point for everything contract-related. The equivalent
# `npm run contracts:*` scripts are kept for people already living in the
# JS toolchain; both call the same underlying forge commands.
#
# Run `make` or `make help` for the target list.
#
# Note: only the contracts live here. The Express/React app is driven by npm
# (`npm start`, `npm run dev`, `npm test`) and is untouched by these targets.
# ---------------------------------------------------------------------------

# Foundry's installer puts binaries in ~/.foundry/bin, which is not always on
# PATH for non-interactive shells (CI, `make` from an editor). Prepend it so
# these targets work regardless of shell profile, while still preferring any
# forge already on PATH.
export PATH := $(PATH):$(HOME)/.foundry/bin

# Deployment config is read from .env by scripts/deploy-contract.js (via dotenv)
# and by foundry.toml (via ${VAR} interpolation). Deliberately NOT `include`d
# here: values like `TOKEN_NAME=Assessment Token` are valid dotenv but would be
# re-parsed by make, so we let one loader own it.

SHELL := /bin/bash
.DEFAULT_GOAL := help

CONTRACT   := ImprovedAssessmentToken
DEPLOY_JS  := node scripts/deploy-contract.js
# script/ is included in coverage: Deploy.s.sol's validation and deployment logic is
# unit-tested via test/Deploy.t.sol. The uncovered remainder is its env-reading and
# broadcast path, which can't be exercised hermetically — see the note in that file.

.PHONY: help install build rebuild clean test test-v test-improved test-legacy \
        test-deploy test-match coverage coverage-lcov gas snapshot snapshot-check sizes \
        fmt fmt-check storage abi anvil deploy-local deploy-sepolia \
        deploy-mainnet ci check-forge

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

help: ## Show this help
	@echo ""
	@echo "  Smart contract targets ($(CONTRACT))"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""

check-forge: ## Verify the Foundry toolchain is installed
	@command -v forge >/dev/null 2>&1 || { \
	  echo ""; \
	  echo "  forge not found on PATH (checked \$$PATH and ~/.foundry/bin)."; \
	  echo "  Install Foundry:  curl -L https://foundry.paradigm.xyz | bash && foundryup"; \
	  echo ""; \
	  exit 1; \
	}

# ---------------------------------------------------------------------------
# Setup & build
# ---------------------------------------------------------------------------

install: ## Fetch pinned Solidity dependencies (OpenZeppelin, forge-std)
	git submodule update --init --recursive

build: check-forge ## Compile the contracts
	forge build

rebuild: clean build ## Force a clean recompile

clean: check-forge ## Remove build artifacts (out/, cache/)
	forge clean

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test: check-forge ## Run the full suite (50 tests)
	forge test

test-v: check-forge ## Run the full suite with traces for failures
	forge test -vvv

test-improved: check-forge ## Run only the ImprovedAssessmentToken suite (24 tests)
	forge test --match-path 'test/ImprovedAssessmentToken.t.sol' -vv

test-legacy: check-forge ## Run only the original-contract characterisation suite (8 tests)
	forge test --match-path 'test/AssessmentToken.legacy.t.sol' -vv

test-deploy: check-forge ## Run only the Deploy script suite (18 tests)
	forge test --match-path 'test/Deploy.t.sol' -vv

test-match: check-forge ## Run tests matching a name: make test-match m=Permit
	@test -n "$(m)" || { echo "usage: make test-match m=<pattern>"; exit 1; }
	forge test --match-test '$(m)' -vvv

coverage: check-forge ## Coverage report for contracts and the deploy script
	forge coverage

coverage-lcov: check-forge ## Write lcov.info for CI / editor coverage gutters
	forge coverage --report lcov
	@echo "wrote lcov.info"

# ---------------------------------------------------------------------------
# Gas & size
# ---------------------------------------------------------------------------

gas: check-forge ## Print a per-function gas report
	forge test --gas-report

snapshot: check-forge ## Write .gas-snapshot for tracking gas over time
	forge snapshot

snapshot-check: check-forge ## Fail if gas changed vs the committed .gas-snapshot
	forge snapshot --check

sizes: check-forge ## Show runtime/initcode sizes against the EIP-170 limit
	forge build --sizes

# ---------------------------------------------------------------------------
# Formatting & inspection
# ---------------------------------------------------------------------------

fmt: check-forge ## Format Solidity (skips the AssessmentToken.sol baseline)
	forge fmt

fmt-check: check-forge ## Fail if Solidity is unformatted
	forge fmt --check

storage: check-forge ## Print the storage layout of both tokens
	@echo "--- AssessmentToken (original) ---"
	@forge inspect contracts/AssessmentToken.sol:AssessmentToken storage
	@echo "--- $(CONTRACT) ---"
	@forge inspect contracts/$(CONTRACT).sol:$(CONTRACT) storage

abi: check-forge ## Print the ABI of the improved token
	@forge inspect contracts/$(CONTRACT).sol:$(CONTRACT) abi

# ---------------------------------------------------------------------------
# Local chain & deployment
#
# Deploys route through scripts/deploy-contract.js, which validates config
# before spending gas and then delegates to script/Deploy.s.sol.
# ---------------------------------------------------------------------------

anvil: check-forge ## Start a local Anvil node on :8545
	anvil

deploy-local: ## Simulate a deploy against localhost (no broadcast)
	$(DEPLOY_JS) --network localhost

deploy-sepolia: ## Broadcast to Sepolia and verify on Etherscan
	$(DEPLOY_JS) --network sepolia --broadcast --verify

deploy-mainnet: ## Broadcast to MAINNET (requires CONFIRM=yes)
	@test "$(CONFIRM)" = "yes" || { \
	  echo ""; \
	  echo "  Refusing to deploy to mainnet without an explicit confirmation."; \
	  echo "  This spends real funds and is irreversible."; \
	  echo ""; \
	  echo "  Re-run as:  make deploy-mainnet CONFIRM=yes"; \
	  echo ""; \
	  exit 1; \
	}
	$(DEPLOY_JS) --network mainnet --broadcast --verify

# ---------------------------------------------------------------------------
# CI
# ---------------------------------------------------------------------------

ci: fmt-check build test ## What CI should run: format check, build, full suite

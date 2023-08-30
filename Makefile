.PHONY: help
help: ## Ask for help!
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## clean.
	@bash -l -c 'forge clean'

.PHONY: build
build: ## Build the smart contracts with foundry.
	@bash -l -c 'forge build'
	script/copy_abis.sh

.PHONY: test
test: ## Run foundry unit tests.
	@bash -l -c 'forge test --no-match-path src/test/forks/**/*.sol'
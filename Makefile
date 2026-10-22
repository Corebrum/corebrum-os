SHELL := bash
.PHONY: lint test dry-run check validate-base validate-desktop

SCRIPTS := $(shell find scripts tests -type f -name '*.sh' | sort)

lint:
	shellcheck -x -P SCRIPTDIR $(SCRIPTS)

test:
	@set -euo pipefail; \
	for t in tests/unit/*.sh tests/smoke/*.sh; do \
		echo "== $$t"; \
		bash "$$t"; \
	done

dry-run:
	./scripts/install.sh --profile base --dry-run
	./scripts/install.sh --profile desktop --dry-run

validate-base:
	./scripts/validate/base.sh

validate-desktop:
	./scripts/validate/desktop.sh

check: lint test dry-run

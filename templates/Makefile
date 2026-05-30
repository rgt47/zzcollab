# zzcollab Makefile v$ZZCOLLAB_TEMPLATE_VERSION
# Docker-first workflow for reproducible research

# Auto-detect from project (no manual configuration needed)
PACKAGE_NAME := $(shell basename $(CURDIR))
PROJECT_NAME := $(PACKAGE_NAME)
R_VERSION := $(shell grep 'R_VERSION=' Dockerfile 2>/dev/null | head -1 | sed 's/.*=//' || echo "4.4.0")

# Git-based versioning for reproducibility (use git SHA or date)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "$(shell date +%Y%m%d)")
IMAGE_TAG = $(GIT_SHA)

# Report rendered by docker-render (override: make docker-render REPORT=path)
REPORT ?= analysis/report/report.Rmd

# Help target (default)
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Validation (runs inside Docker, no host R required):"
	@echo "    check-renv             - Full validation: strict + auto-fix (recommended)"
	@echo "    check-renv-no-fix      - Report only, no modifications"
	@echo "    check-renv-no-strict   - Skip tests/ and vignettes/"
	@echo ""
	@echo "  Main workflow (RECOMMENDED):"
	@echo "    r                     - Start bash terminal (vim editing, all profiles)"
	@echo "    rstudio               - Start RStudio Server on http://localhost:8787"
	@echo ""
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo ""
	@echo "  Docker utilities:"
	@echo "    docker-build          - Pre-build audit then build image from renv.lock"
	@echo "    check-binaries        - Audit renv.lock for missing system deps (pre-build)"
	@echo "    docker-rebuild        - Rebuild image without cache (force fresh build)"
	@echo "    docker-build-log      - Build with detailed logs (for debugging)"
	@echo "    docker-push-team, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-render-qmd"
	@echo "    docker-check-renv"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean, docker-clean"
	@echo "    docker-prune-cache       - Remove Docker build cache"
	@echo "    docker-prune-all         - Deep clean (all unused Docker resources)"
	@echo "    docker-disk-usage        - Show Docker disk usage"

# Native R targets (require local R installation)
document:
	R --quiet -e "devtools::document()"

build:
	R CMD build .

check: document
	R CMD check --as-cran *.tar.gz

install: document
	R --quiet -e "devtools::install()"

vignettes: document
	R --quiet -e "devtools::build_vignettes()"

test:
	R --quiet -e "tinytest::run_test_dir('inst/tinytest')"

deps:
	R --quiet -e "devtools::install_deps(dependencies = TRUE)"

# Validate package dependencies using zzrenvcheck inside the Docker container.
# Scans R/, analysis/, scripts/ (and tests/, vignettes/ in strict mode) for
# library()/require()/:: calls, then checks DESCRIPTION and renv.lock are in sync.
# Run before `git commit` to catch issues locally and prevent CI failures.

# Full validation: strict mode + auto-fix missing packages
check-renv:
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)"

# Report only: identify gaps without modifying DESCRIPTION or renv.lock
check-renv-no-fix:
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = FALSE, strict = TRUE)"

# Non-strict: skip tests/ and vignettes/ directories
check-renv-no-strict:
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = TRUE, strict = FALSE)"

# Docker targets (work without local R)
# Docker-first workflow:
#   1. Work in containers (make r)
#   2. Install packages (renv::install("pkg"))
#   3. Exit container (auto-snapshot on exit)
#   4. Build new image (make docker-build)

# Pre-build audit: check renv.lock packages against PPM for missing system
# dependencies and packages that will compile from source.
# Requires python3 (standard on macOS/Linux). Pass SKIP_AUDIT=1 to bypass.
check-binaries:
	@if [ -f tools/check-binaries.py ]; then \
		python3 tools/check-binaries.py \
			--renv-lock renv.lock \
			--dockerfile Dockerfile; \
	else \
		echo "  tools/check-binaries.py not found, skipping audit"; \
	fi

docker-build: check-binaries
	zzcollab build

docker-rebuild:
	zzcollab build --no-cache

docker-build-log:
	zzcollab build --log

docker-push-team:
	@echo "Tagging image as $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	docker tag $(PACKAGE_NAME) $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "Pushing to Docker Hub..."
	docker push $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "✅ Team image pushed: $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	@echo "   Team members should update .zzcollab_team_setup to reference this tag"

docker-document:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::document()"

docker-build-pkg:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "tinytest::run_test_dir('inst/tinytest')"

docker-vignettes: docker-document
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::build_vignettes()"

docker-render:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "rmarkdown::render('$(REPORT)')"

# Run an arbitrary R script in the container (used by zzcollab::run_script)
docker-script:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) Rscript -e "source('$(SCRIPT)')"

docker-render-qmd:
	docker run --rm -v $$(pwd):/home/analyst/project -w /home/analyst/project $(PACKAGE_NAME) quarto render analysis/report/index.qmd

docker-check-renv:
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = FALSE, strict = TRUE)"

docker-check-renv-fix:
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)"

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: rstudio, Password: rstudio"
	@echo "Terminal available for code editing with vim"
	docker run --rm -it -p 8787:8787 -v $$(pwd):/home/rstudio/project $(PACKAGE_NAME) /init

# Terminal: Interactive bash for vim editing
r: check-renv
	@if [ ! -f Dockerfile ]; then \
		echo ""; \
		echo "❌ No Dockerfile found - workspace not initialized"; \
		echo ""; \
		echo "Run zzcollab to create a Docker environment:"; \
		echo ""; \
		echo "  zzcollab docker                            # default profile"; \
		echo "  zzcollab docker --profile analysis         # tidyverse"; \
		echo "  zzcollab docker --profile publishing       # with LaTeX"; \
		echo ""; \
		echo "See: zzcollab docker --help for all options"; \
		echo ""; \
		exit 1; \
	fi; \
	echo "🔍 Checking workspace..."; \
	BASE_IMAGE=$$(grep '^ARG BASE_IMAGE=' Dockerfile | head -1 | cut -d= -f2); \
	PROFILE=$$(echo "$$BASE_IMAGE" | sed 's|.*/||; s|tidyverse|analysis|; s|verse|publishing|; s|r-ver|minimal|'); \
	USERNAME=$$(grep '^ARG USERNAME=' Dockerfile | head -1 | cut -d= -f2); \
	USERNAME=$${USERNAME:-analyst}; \
	HOME_DIR="/home/$$USERNAME"; \
	echo "🐳 Starting R ($$PROFILE)..."; \
	echo ""; \
	mkdir -p $$HOME/.cache/R/renv 2>/dev/null || true; \
	docker run --rm -it \
		-v $$(pwd):$$HOME_DIR/project \
		-v $$HOME/.cache/R/renv:$$HOME_DIR/.cache/R/renv \
		-w $$HOME_DIR/project \
		-e KITTY_WINDOW_ID="$${KITTY_WINDOW_ID:-}" \
		-e ITERM_SESSION_ID="$${ITERM_SESSION_ID:-}" \
		-e TERM_PROGRAM="$${TERM_PROGRAM:-}" \
		-e GHOSTTY_RESOURCES_DIR="$${GHOSTTY_RESOURCES_DIR:-}" \
		-e WEZTERM_EXECUTABLE="$${WEZTERM_EXECUTABLE:-}" \
		$(PACKAGE_NAME) R; \
	echo ""; \
	echo "📋 Post-session validation..."; \
	docker run --rm \
		-v $$(pwd):/home/analyst/project \
		-w /home/analyst/project \
		$(PACKAGE_NAME) \
		Rscript -e "zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)" \
	|| echo "⚠️  Package validation failed"

# Alias for rstudio
rstudio: docker-rstudio

# Cleanup
clean:
	rm -f *.tar.gz
	rm -rf *.Rcheck

docker-clean:
	docker rmi $(PACKAGE_NAME) || true
	docker system prune -f

# Docker disk management
docker-disk-usage:
	@echo "Docker disk usage:"
	@docker system df

docker-prune-cache:
	@echo "Removing Docker build cache..."
	docker builder prune -af
	@echo "✅ Build cache cleaned"
	@make docker-disk-usage

docker-prune-all:
	@echo "WARNING: This will remove all unused Docker images, containers, and build cache"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read dummy
	@echo "Removing all unused Docker resources..."
	docker system prune -af
	@echo "✅ Docker cleanup complete"
	@make docker-disk-usage

.PHONY: all document build check install vignettes test deps check-renv check-renv-no-fix check-renv-no-strict check-binaries docker-build docker-rebuild docker-build-log docker-push-team docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-render-qmd docker-rstudio r docker-check-renv docker-check-renv-fix clean docker-clean docker-disk-usage docker-prune-cache docker-prune-all help

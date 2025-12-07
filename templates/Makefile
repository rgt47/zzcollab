# Makefile for ${PKG_NAME} research compendium
# Docker-first workflow for reproducible research

PACKAGE_NAME = ${PKG_NAME}
R_VERSION = ${R_VERSION}
TEAM_NAME = ${TEAM_NAME}
PROJECT_NAME = ${PROJECT_NAME}
DOCKERHUB_ACCOUNT = ${DOCKERHUB_ACCOUNT}

# Git-based versioning for reproducibility (use git SHA or date)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "$(shell date +%Y%m%d)")
IMAGE_TAG = $(GIT_SHA)

# Help target (default)
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Validation (NO HOST R REQUIRED!):"
	@echo "    check-renv            - Full validation: strict + auto-fix (recommended)"
	@echo "    check-renv-no-fix     - Validation only, no auto-install"
	@echo "    check-renv-no-strict  - Standard mode (skip tests/, vignettes/)"
	@echo ""
	@echo "  Main workflow (RECOMMENDED):"
	@echo "    r                     - Start bash terminal (vim editing, all profiles)"
	@echo "    rstudio               - Start RStudio Server on http://localhost:8787"
	@echo ""
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo ""
	@echo "  Docker utilities:"
	@echo "    docker-build          - Build image from current renv.lock"
	@echo "    docker-rebuild        - Rebuild image without cache (force fresh build)"
	@echo "    docker-build-log      - Build with detailed logs (for debugging)"
	@echo "    docker-push-team, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-check-renv"
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
	R --quiet -e "devtools::test()"

deps:
	R --quiet -e "devtools::install_deps(dependencies = TRUE)"

# Validate package dependencies (Pure shell, NO HOST R REQUIRED!)
# Checks that all packages used in code are in DESCRIPTION and renv.lock
# Full validation with strict mode, auto-fix, and verbose output (DEFAULT behavior)
# Scans all directories (root, R/, scripts/, analysis/, tests/, vignettes/, inst/)
# Auto-adds missing packages to DESCRIPTION and renv.lock
# Run this before `git commit` to catch issues locally (prevents CI failures)
check-renv:
	@bash modules/validation.sh --fix --strict --verbose

# Validation only, no auto-fix (report issues without modifying files)
check-renv-no-fix:
	@bash modules/validation.sh --no-fix --strict --verbose

# Standard mode validation (skip tests/, vignettes/, inst/ directories)
check-renv-no-strict:
	@bash modules/validation.sh --fix --verbose

# Legacy: R-based validation (for CI/CD that has R pre-installed)
# This is the old approach, kept for backward compatibility
check-renv-ci:
	@bash modules/validation.sh --fix --strict --verbose

# Docker targets (work without local R)
# Docker-first workflow:
#   1. Work in containers (make r or make docker-run)
#   2. Install packages (renv::install("pkg"))
#   3. Exit container (auto-snapshot on exit)
#   4. Build new image (make docker-build)
docker-build:
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

docker-rebuild:
	DOCKER_BUILDKIT=1 docker build --no-cache --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

docker-build-log:
	@echo "Building Docker image and saving log to docker-build.log..."
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --progress=plain --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) . 2>&1 | tee docker-build.log
	@echo "✅ Build complete. Log saved to docker-build.log"

docker-push-team:
	@echo "Tagging image as $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	docker tag $(PACKAGE_NAME) $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "Pushing to Docker Hub..."
	docker push $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "✅ Team image pushed: $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	@echo "   Team members should update .zzcollab_team_setup to reference this tag"

docker-document:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::document()"

docker-build-pkg:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::test()"

docker-vignettes: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::build_vignettes()"

docker-render:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "rmarkdown::render('analysis/paper/paper.Rmd')"

docker-check-renv:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "renv::status()"

docker-check-renv-fix:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "renv::snapshot()"

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: rstudio, Password: rstudio"
	@echo "Terminal available for code editing with vim"
	docker run --platform linux/amd64 --rm -it -p 8787:8787 -v $$(pwd):/home/rstudio/project $(PACKAGE_NAME) /init

# Terminal: Interactive bash for vim editing
r: check-renv
	@PROFILE=$$(head -20 Dockerfile | grep 'Profile:' | head -1 | sed 's/.*Profile: \([a-z0-9_]*\).*/\1/'); \
	if [ -z "$$PROFILE" ]; then \
		echo "❌ Could not detect profile from Dockerfile"; \
		exit 1; \
	fi; \
	BASE_IMAGE=$$(grep '^FROM' Dockerfile | head -1 | awk '{print $$2}' | sed 's/--platform[^[:space:]]*[[:space:]]//'); \
	if echo "$$BASE_IMAGE" | grep -qE '(rocker/verse|rocker/tidyverse|rocker/rstudio|rocker/geospatial)'; then \
		HOME_DIR="/home/rstudio"; \
	else \
		HOME_DIR="/home/analyst"; \
	fi; \
	echo "🐳 Starting bash terminal ($$PROFILE)..."; \
	echo "📝 Use vim, R, or any terminal tools"; \
	echo ""; \
	docker run --platform linux/amd64 --rm -it -v $$(pwd):$$HOME_DIR/project -v $$(pwd)/.cache/R/renv:$$HOME_DIR/.cache/R/renv $(PACKAGE_NAME); \
	echo ""; \
	echo "📋 Post-session validation..."; \
	bash modules/validation.sh --fix --strict --verbose || echo "⚠️  Package validation failed"

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

.PHONY: all document build check install vignettes test deps check-renv check-renv-no-fix check-renv-no-strict check-renv-ci docker-build docker-rebuild docker-build-log docker-push-team docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-rstudio docker-run r docker-check-renv docker-check-renv-fix clean docker-clean docker-disk-usage docker-prune-cache docker-prune-all help

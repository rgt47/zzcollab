# Makefile for zzcollab research compendium
# Docker-first workflow for reproducible research

PACKAGE_NAME = zzcollab
R_VERSION = latest

# Help target (default)
help:
	@echo "Available targets:"
	@echo "  Validation (NO HOST R REQUIRED!):"
	@echo "    check-renv            - Full validation: strict + auto-fix + verbose (recommended)"
	@echo "    check-renv-no-fix     - Validation only, no auto-fix"
	@echo "    check-renv-no-strict  - Standard mode (skip tests/, vignettes/, inst/)"
	@echo "    check-renv-ci         - CI/CD validation (same as check-renv)"
	@echo ""
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    r                     - Start container (RECOMMENDED! Auto-detects profile, mounts cache)"
	@echo "    docker-run            - Same as 'make r' (auto-detects profile, mounts cache)"
	@echo "    docker-build          - Build image (safe: auto-snapshots renv.lock first)"
	@echo "    docker-build-no-snapshot - Build without snapshot (advanced)"
	@echo "    docker-rstudio        - Start RStudio Server"
	@echo "    docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-check-renv"
	@echo "    docker-check-renv-fix"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean, docker-clean"
	@echo "    docker-prune-cache       - Remove Docker build cache"
	@echo "    docker-prune-all         - Deep clean (all unused Docker resources)"
	@echo "    docker-disk-usage        - Show Docker disk usage"

# Native R targets (require local R installation)
document:
	R -e "devtools::document()"

build:
	R CMD build .

check: document
	R CMD check --as-cran *.tar.gz

install: document
	R -e "devtools::install()"

vignettes: document
	R -e "devtools::build_vignettes()"

test: shell-test
	R -e "devtools::test()"

shell-test:
	@echo "Running shell unit tests..."
	@bash tests/shell/run_all_tests.sh

shell-test-verbose:
	@echo "Running shell unit tests (verbose)..."
	@bash tests/shell/run_all_tests.sh --verbose

shell-test-core:
	@echo "Testing core.sh module..."
	@bash tests/shell/test-core.sh

shell-test-validation:
	@echo "Testing validation.sh module..."
	@bash tests/shell/test-validation.sh

shell-test-cli:
	@echo "Testing cli.sh module..."
	@bash tests/shell/test-cli.sh

deps:
	R -e "devtools::install_deps(dependencies = TRUE)"

check-renv:
	@./zzcollab.sh validate --fix --strict --verbose

check-renv-no-fix:
	@./zzcollab.sh validate --no-fix --strict --verbose

check-renv-no-strict:
	@./zzcollab.sh validate --fix --verbose

check-renv-ci:
	@./zzcollab.sh validate --fix --strict --verbose

# Docker targets (work without local R)
# SAFETY IMPROVEMENT: docker-build is now safe by default
#   - Automatically runs renv::snapshot() to update renv.lock
#   - Ensures Docker image matches your current R environment
#   - Critical for automatic RSPM date detection from renv.lock
docker-build: check-renv-fix docker-build-no-snapshot

# Advanced: Build without updating renv.lock (rarely needed)
# Use this only when:
#   - Debugging Dockerfile changes (no package changes)
#   - You know renv.lock is already up-to-date
#   - Faster iteration during Dockerfile development
docker-build-no-snapshot:
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

# DEPRECATED: Use docker-build instead (now safe by default)
docker-build-safe:
	@echo "⚠️  WARNING: 'docker-build-safe' is deprecated."
	@echo "           'docker-build' is now safe by default (auto-snapshots renv.lock)."
	@echo "           Please use 'docker-build' instead."
	@echo ""
	@$(MAKE) docker-build

docker-document:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "devtools::document()"

docker-build-pkg:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "devtools::test()"

docker-vignettes: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "devtools::build_vignettes()"

docker-render:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "rmarkdown::render('analysis/report/report.Rmd')"

docker-check-renv:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "renv::status()"

docker-check-renv-fix:
	docker run --platform linux/amd64 --rm -v $$(pwd):/project $(PACKAGE_NAME) R -e "renv::snapshot()"

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: analyst, Password: analyst"
	docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init

# Quick alias: 'make r' runs the last built image (same as docker-run)
r: docker-run

# Smart docker-run: Automatically detect profile and run appropriately
docker-run:
	@if [ ! -f Dockerfile ]; then \
		echo "❌ No Dockerfile found in current directory"; \
		exit 1; \
	fi
	@PROFILE=$$(head -20 Dockerfile | grep -o 'Profile: [a-z0-9_]*' | head -1 | cut -d' ' -f2); \
	if [ -z "$$PROFILE" ]; then \
		echo "❌ Could not detect profile from Dockerfile"; \
		echo "   Add '# Profile: <name>' comment to Dockerfile header"; \
		exit 1; \
	fi; \
	echo "🔍 Detected profile: $$PROFILE"; \
	echo ""; \
	case "$$PROFILE" in \
		ubuntu_standard_minimal|alpine_standard_minimal) \
			echo "🐳 Starting minimal profile (sh shell)..."; \
			docker run --platform linux/amd64 --rm -it -v $$(pwd):/project $(PACKAGE_NAME) /bin/sh; \
			;; \
		ubuntu_x11_minimal|alpine_x11_minimal) \
			echo "🐳 Starting X11 minimal profile (GUI support)..."; \
			echo "Setting up X11 forwarding..."; \
			if ! command -v xquartz >/dev/null 2>&1 && ! [ -d /Applications/Utilities/XQuartz.app ]; then \
				echo "❌ XQuartz not found. Installing..."; \
				brew install --cask xquartz; \
				echo "⚠️  XQuartz installed. Please log out and log back in, then run this command again."; \
				exit 1; \
			fi; \
			CURRENT_SETTING=$$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo "1"); \
			if [ "$$CURRENT_SETTING" != "0" ]; then \
				echo "Configuring XQuartz to allow network connections..."; \
				defaults write org.xquartz.X11 nolisten_tcp 0; \
				echo "⚠️  XQuartz configuration updated. Restarting XQuartz..."; \
				killall XQuartz 2>/dev/null || killall Xquartz 2>/dev/null || true; \
				sleep 1; \
			fi; \
			if ! pgrep -x "XQuartz" >/dev/null && ! pgrep -x "Xquartz" >/dev/null; then \
				echo "Starting XQuartz..."; \
				open -a XQuartz; \
				sleep 3; \
			fi; \
			if command -v xhost >/dev/null 2>&1; then \
				xhost +localhost >/dev/null 2>&1 || true; \
			fi; \
			echo "✅ X11 setup complete"; \
			echo ""; \
			DISPLAY=:0 docker run --platform linux/amd64 --rm -it -v $$(pwd):/project -e DISPLAY=host.docker.internal:0 $(PACKAGE_NAME) /bin/sh; \
			;; \
		ubuntu_standard_analysis|alpine_standard_analysis) \
			echo "🐳 Starting standard analysis profile (RStudio Server)..."; \
			echo "📊 RStudio: http://localhost:8787"; \
			echo "👤 Username: analyst, Password: analyst"; \
			echo ""; \
			docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init; \
			;; \
		ubuntu_x11_analysis|alpine_x11_analysis) \
			echo "🐳 Starting X11 analysis profile (GUI + RStudio Server)..."; \
			echo "Setting up X11 forwarding..."; \
			if ! command -v xquartz >/dev/null 2>&1 && ! [ -d /Applications/Utilities/XQuartz.app ]; then \
				echo "❌ XQuartz not found. Installing..."; \
				brew install --cask xquartz; \
				echo "⚠️  XQuartz installed. Please log out and log back in, then run this command again."; \
				exit 1; \
			fi; \
			CURRENT_SETTING=$$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo "1"); \
			if [ "$$CURRENT_SETTING" != "0" ]; then \
				echo "Configuring XQuartz to allow network connections..."; \
				defaults write org.xquartz.X11 nolisten_tcp 0; \
				echo "⚠️  XQuartz configuration updated. Restarting XQuartz..."; \
				killall XQuartz 2>/dev/null || killall Xquartz 2>/dev/null || true; \
				sleep 1; \
			fi; \
			if ! pgrep -x "XQuartz" >/dev/null && ! pgrep -x "Xquartz" >/dev/null; then \
				echo "Starting XQuartz..."; \
				open -a XQuartz; \
				sleep 3; \
			fi; \
			if command -v xhost >/dev/null 2>&1; then \
				xhost +localhost >/dev/null 2>&1 || true; \
			fi; \
			echo "✅ X11 setup complete"; \
			echo ""; \
			echo "📊 RStudio: http://localhost:8787"; \
			echo "👤 Username: analyst, Password: analyst"; \
			echo ""; \
			DISPLAY=:0 docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/project -e USER=analyst -e PASSWORD=analyst -e DISPLAY=host.docker.internal:0 $(PACKAGE_NAME) /init; \
			;; \
		ubuntu_shiny_minimal|ubuntu_shiny_analysis) \
			echo "🐳 Starting Shiny Server ($$PROFILE)..."; \
			echo "📊 Shiny: http://localhost:3838"; \
			echo ""; \
			docker run --platform linux/amd64 --rm -p 3838:3838 -v $$(pwd):/project $(PACKAGE_NAME); \
			;; \
		ubuntu_standard_publishing) \
			echo "🐳 Starting publishing profile (RStudio Server + LaTeX + Quarto)..."; \
			echo "📊 RStudio: http://localhost:8787"; \
			echo "👤 Username: analyst, Password: analyst"; \
			echo ""; \
			docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init; \
			;; \
		*) \
			echo "❌ Unknown profile: $$PROFILE"; \
			echo "   Supported profiles:"; \
			echo "     Minimal: ubuntu_standard_minimal, alpine_standard_minimal"; \
			echo "     X11: ubuntu_x11_minimal, alpine_x11_minimal"; \
			echo "     Analysis: ubuntu_standard_analysis, alpine_standard_analysis"; \
			echo "     X11 Analysis: ubuntu_x11_analysis, alpine_x11_analysis"; \
			echo "     Shiny: ubuntu_shiny_minimal, ubuntu_shiny_analysis"; \
			echo "     Publishing: ubuntu_standard_publishing"; \
			exit 1; \
			;; \
	esac

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

.PHONY: all document build check install vignettes test deps check-renv check-renv-no-fix check-renv-no-strict check-renv-ci docker-build docker-build-no-snapshot docker-build-safe docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-rstudio docker-run r docker-check-renv docker-check-renv-fix clean docker-clean docker-disk-usage docker-prune-cache docker-prune-all help

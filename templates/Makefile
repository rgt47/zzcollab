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
	@echo "    check-renv            - Pure shell validation (recommended)"
	@echo "    check-renv-strict     - Strict mode (scan tests/, vignettes/)"
	@echo ""
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo "    check-renv-fix, check-renv-ci (legacy)"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    docker-build          - Build image (safe: auto-snapshots renv.lock first)"
	@echo "    docker-build-no-snapshot - Build without snapshot (advanced)"
	@echo "    docker-r, docker-bash, docker-zsh, docker-rstudio"
	@echo "    docker-build-log, docker-push-team, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-check-renv"
	@echo "    docker-check-renv-fix"
	@echo "    All docker-* targets auto-snapshot renv.lock on exit and validate packages!"
	@echo ""
	@echo "  Docker GUI (requires XQuartz):"
	@echo "    docker-zsh-gui        - Launch zsh with X11 forwarding (xfce4-terminal, GUI apps)"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean, clean-dotfiles, docker-clean, docker-build-clean"
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

test:
	R -e "devtools::test()"

deps:
	R -e "devtools::install_deps(dependencies = TRUE)"

check-renv:
	R -e "renv::status()"

check-renv-fix:
	R -e "renv::snapshot()"

# Validate package dependencies (NEW: Pure shell, no host R required!)
# Checks that all packages used in code are in DESCRIPTION and renv.lock
# Run this before `git commit` to catch issues locally (prevents CI failures)
check-renv:
	@bash modules/validation.sh

# Validate in strict mode (scan all directories including tests/)
check-renv-strict:
	@bash modules/validation.sh --strict

# Legacy: R-based validation (for CI/CD that has R pre-installed)
# This is the old approach, kept for backward compatibility
check-renv-ci:
	Rscript validate_package_environment.R --quiet --fail-on-issues

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
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::document()"

docker-build-pkg:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::test()"

docker-vignettes: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::build_vignettes()"

docker-render:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "rmarkdown::render('analysis/paper/paper.Rmd')"

docker-check-renv:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "renv::status()"

docker-check-renv-fix:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "renv::snapshot()"

docker-r:
	@echo "🐳 Starting Docker container (auto-snapshot on exit)..."
	@docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R
	@echo "📋 Validating package dependencies..."
	@bash modules/validation.sh || echo "⚠️  Package validation failed - see above for details"
	@if [ -f renv.lock ]; then touch renv.lock; fi

docker-bash:
	@echo "🐳 Starting Docker container (auto-snapshot on exit)..."
	@docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) /bin/bash
	@echo "📋 Validating package dependencies..."
	@bash modules/validation.sh || echo "⚠️  Package validation failed - see above for details"
	@if [ -f renv.lock ]; then touch renv.lock; fi

docker-zsh:
	@echo "🐳 Starting Docker container (auto-snapshot on exit)..."
	@docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) /bin/zsh
	@echo "📋 Validating package dependencies..."
	@bash modules/validation.sh || echo "⚠️  Package validation failed - see above for details"
	@if [ -f renv.lock ]; then touch renv.lock; fi

docker-zsh-gui:
	@echo "Setting up X11 forwarding for GUI apps..."
	@# Check if XQuartz is installed
	@if ! command -v xquartz >/dev/null 2>&1 && ! [ -d /Applications/Utilities/XQuartz.app ]; then \
		echo "❌ XQuartz not found. Installing..."; \
		brew install --cask xquartz; \
		echo "⚠️  XQuartz installed. Please log out and log back in, then run this command again."; \
		exit 1; \
	fi
	@# Configure XQuartz to allow network connections
	@CURRENT_SETTING=$$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo "1"); \
	if [ "$$CURRENT_SETTING" != "0" ]; then \
		echo "Configuring XQuartz to allow network connections..."; \
		defaults write org.xquartz.X11 nolisten_tcp 0; \
		echo "⚠️  XQuartz configuration updated. Restarting XQuartz..."; \
		killall XQuartz 2>/dev/null || killall Xquartz 2>/dev/null || true; \
		sleep 1; \
	fi
	@# Check if XQuartz is running, start it if not
	@if ! pgrep -x "XQuartz" >/dev/null && ! pgrep -x "Xquartz" >/dev/null; then \
		echo "Starting XQuartz..."; \
		open -a XQuartz; \
		sleep 3; \
	fi
	@# Set DISPLAY and allow connections
	@export DISPLAY=:0 && \
	if command -v xhost >/dev/null 2>&1; then \
		xhost +localhost >/dev/null 2>&1 || true; \
	fi
	@echo "✅ X11 setup complete"
	@echo ""
	@echo "GUI apps available: xfce4-terminal, firefox, etc."
	@echo "Run 'xfce4-terminal' to open a GUI terminal window"
	@echo ""
	@echo "🐳 Starting Docker container (auto-snapshot on exit)..."
	@DISPLAY=:0 docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project -e DISPLAY=host.docker.internal:0 $(PACKAGE_NAME) /bin/zsh
	@echo "📋 Validating package dependencies..."
	@bash modules/validation.sh || echo "⚠️  Package validation failed - see above for details"
	@if [ -f renv.lock ]; then touch renv.lock; fi

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: analyst, Password: analyst"
	docker run --platform linux/amd64 --rm --user root -p 8787:8787 -v $$(pwd):/home/analyst/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init

# Cleanup
clean:
	rm -f *.tar.gz
	rm -rf *.Rcheck

clean-dotfiles:
	@echo "Cleaning up dotfiles from working directory..."
	@rm -f .vimrc .tmux.conf .gitconfig .inputrc .bashrc .bash_profile .profile .aliases .functions .exports .editorconfig .ctags .ackrc .ripgreprc .zshrc .zshrc_docker .emacs 2>/dev/null || true
	@rm -rf .emacs.d .config/fish 2>/dev/null || true
	@echo "Dotfiles cleanup complete (preserved in Docker image)"

docker-clean:
	docker rmi $(PACKAGE_NAME) || true

docker-build-clean: docker-build clean-dotfiles
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

.PHONY: all document build check install vignettes test deps check-renv check-renv-fix check-renv-ci docker-build docker-build-no-snapshot docker-build-safe docker-build-log docker-push-team docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-r docker-bash docker-zsh docker-zsh-gui docker-rstudio docker-check-renv docker-check-renv-fix clean clean-dotfiles docker-clean docker-build-clean docker-disk-usage docker-prune-cache docker-prune-all help

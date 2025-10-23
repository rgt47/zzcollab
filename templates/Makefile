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
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo "    check-renv, check-renv-fix, check-renv-ci"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    docker-build, docker-build-log, docker-push-team, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-check-renv"
	@echo "    docker-check-renv-fix, docker-r, docker-bash, docker-zsh, docker-rstudio"
	@echo ""
	@echo "  Docker GUI (requires XQuartz):"
	@echo "    docker-zsh-gui           - Launch zsh with X11 forwarding (kitty, GUI apps)"
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

# Validate package dependencies before committing (RECOMMENDED)
# Checks that all packages used in code are in DESCRIPTION and renv.lock
# Run this before `git commit` to catch issues locally (prevents CI failures)
check-renv-ci:
	Rscript validate_package_environment.R --quiet --fail-on-issues

# Docker targets (work without local R)
docker-build:
	DOCKER_BUILDKIT=1 docker build --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

docker-build-log:
	@echo "Building Docker image and saving log to docker-build.log..."
	DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) . 2>&1 | tee docker-build.log
	@echo "✅ Build complete. Log saved to docker-build.log"

docker-push-team:
	@echo "Tagging image as $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	docker tag $(PACKAGE_NAME) $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "Pushing to Docker Hub..."
	docker push $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "✅ Team image pushed: $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	@echo "   Team members should update .zzcollab_team_setup to reference this tag"

docker-document:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::document()"

docker-build-pkg:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::test()"

docker-vignettes: docker-document
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "devtools::build_vignettes()"

docker-render:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "rmarkdown::render('analysis/paper/paper.Rmd')"

docker-check-renv:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "renv::status()"

docker-check-renv-fix:
	docker run --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R -e "renv::snapshot()"

docker-r:
	docker run --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R

docker-bash:
	docker run --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) /bin/bash

docker-zsh:
	docker run --rm -it -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) /bin/zsh

docker-zsh-gui:
	@echo "Launching zsh with X11 forwarding enabled"
	@echo "GUI apps available: kitty, firefox, etc."
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. XQuartz installed: brew install --cask xquartz"
	@echo "  2. XQuartz running with 'Allow connections from network clients' enabled"
	@echo "  3. Run: xhost +localhost"
	@echo ""
	docker run --rm -it -v $$(pwd):/home/analyst/project -e DISPLAY=host.docker.internal:0 $(PACKAGE_NAME) /bin/zsh

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: analyst, Password: analyst"
	docker run --rm --user root -p 8787:8787 -v $$(pwd):/home/analyst/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init

# Cleanup
clean:
	rm -f *.tar.gz
	rm -rf *.Rcheck

clean-dotfiles:
	@echo "Cleaning up dotfiles from working directory..."
	@rm -f .vimrc .tmux.conf .gitconfig .inputrc .bashrc .profile .aliases .functions .exports .editorconfig .ctags .ackrc .ripgreprc .zshrc_docker 2>/dev/null || true
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

.PHONY: all document build check install vignettes test deps check-renv check-renv-fix check-renv-ci docker-build docker-push-team docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-r docker-bash docker-zsh docker-zsh-gui docker-rstudio docker-check-renv docker-check-renv-fix clean clean-dotfiles docker-clean docker-build-clean docker-disk-usage docker-prune-cache docker-prune-all help

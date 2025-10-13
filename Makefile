# Makefile for zzcollab research compendium
# Docker-first workflow for reproducible research

PACKAGE_NAME = zzcollab
R_VERSION = latest

# Help target (default)
help:
	@echo "Available targets:"
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo "    check-renv, check-renv-fix, check-renv-ci"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    docker-build, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-check-renv"
	@echo "    docker-check-renv-fix, docker-r, docker-bash, docker-zsh, docker-rstudio"
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

test:
	R -e "devtools::test()"

deps:
	R -e "devtools::install_deps(dependencies = TRUE)"

check-renv:
	R -e "renv::status()"

check-renv-fix:
	R -e "renv::snapshot()"

check-renv-ci:
	Rscript validate_package_environment.R --quiet --fail-on-issues

# Docker targets (work without local R)
docker-build:
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

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

docker-r:
	docker run --platform linux/amd64 --rm -it -v $$(pwd):/project $(PACKAGE_NAME) R

docker-bash:
	docker run --platform linux/amd64 --rm -it -v $$(pwd):/project $(PACKAGE_NAME) /bin/bash

docker-zsh:
	docker run --platform linux/amd64 --rm -it -v $$(pwd):/project $(PACKAGE_NAME) /bin/zsh

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: analyst, Password: analyst"
	docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init

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

.PHONY: all document build check install vignettes test deps check-renv check-renv-fix check-renv-ci docker-build docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-r docker-bash docker-zsh docker-rstudio docker-check-renv docker-check-renv-fix clean docker-clean docker-disk-usage docker-prune-cache docker-prune-all help

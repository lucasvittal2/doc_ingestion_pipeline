#* Variables
SHELL := /usr/bin/env bash
PYTHON := python3.10
PYTHONPATH := $(shell pwd)

#* Set POETRY to the path of the Poetry executable
POETRY := $(shell command -v poetry)

#* Docker variables
IMAGE := doc_ingestion_pipeline
VERSION := $(shell poetry version --short)
TAG := $(shell echo "latest")

#* Wheel Path
WHEEL_PATH := src/doc_ingestion_pipeline/

#* GCloud Authentication (only if not logged in)
.PHONY: gcloud-auth
gcloud-auth:
	@printf "[Makefile] - Checking Google Cloud authentication status...\n"
	@if ! gcloud auth application-default print-access-token > /dev/null 2>&1; then \
		printf "[Makefile] - Not authenticated. Running gcloud login...\n"; \
		gcloud auth application-default login; \
		gcloud auth login; \
	else \
		printf "[Makefile] - Already authenticated with Google Cloud.\n"; \
	fi
	@printf "\n[Makefile] - Configuring Docker to use gcloud as a credential helper...\n"
	@gcloud auth configure-docker
	@printf "[Makefile] - Google Cloud authentication and Docker configuration complete.\n\n"

#* Python environment
.PHONY: create-venv
create-venv:
	@printf "[Makefile] - Checking if Homebrew is installed...\n"
	@if ! command -v brew > /dev/null 2>&1; then \
		printf "[Makefile] - Homebrew not found. Installing Homebrew...\n"; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		printf "[Makefile] - Homebrew is already installed!\n"; \
	fi
	@printf "[Makefile] - Ensuring 3.10 is installed...\n"
	@if ! brew list python@3.10 > /dev/null 2>&1; then \
		printf "[Makefile] - 3.10 not found. Installing 3.10 via Homebrew...\n"; \
		brew install python@3.10; \
	else \
		printf "[Makefile] - 3.10 is already installed!\n"; \
	fi
	@printf "[Makefile] - Linking 3.10 to be the default Python...\n"
	@brew link --overwrite python@3.10
	@printf "[Makefile] - Creating a virtual environment named 'doc-ingestion-pipeline-3.10'...\n"
	@if [ ! -d "doc-ingestion-pipeline-3.10" ]; then \
		python3.10 -m venv doc-ingestion-pipeline-3.10; \
	else \
		printf "[Makefile] - Virtual environment 'doc-ingestion-pipeline-3.10' already exists!\n"; \
	fi
	@printf "[Makefile] - Virtual environment setup complete. To activate, run:\n"
	@printf "[Makefile] - 'source doc-ingestion-pipeline-3.10/bin/activate'\n"

#* Activate the virtual environment
.PHONY: activate-venv
activate-venv:
	@printf "[Makefile] - Activating the virtual environment 'doc-ingestion-pipeline-3.10'...\n"
	@source doc-ingestion-pipeline-3.10/bin/activate && printf "[Makefile] - Virtual environment activated!\n"


.PHONY: poetry-download
poetry-download:
	@printf "[Makefile] - Attempting to install Poetry...\n"
	@if ! command -v poetry > /dev/null 2>&1; then \
		if command -v brew > /dev/null 2>&1 && ! brew list poetry > /dev/null 2>&1; then \
			printf "[Makefile] - Homebrew found. Installing Poetry via Homebrew...\n"; \
			brew install poetry || printf "[Makefile] - Failed to install Poetry via Homebrew. Attempting to install via script...\n"; \
		fi; \
		if ! command -v poetry > /dev/null 2>&1; then \
			printf "[Makefile] - Installing Poetry via official script...\n"; \
			curl -sSL https://install.python-poetry.org | python3 -; \
		fi; \
		if command -v poetry > /dev/null 2>&1; then \
		  	export PATH="$$HOME/.poetry/bin:$$PATH"; \
			printf "[Makefile] - Poetry installed successfully.\n"; \
		else \
			printf "[Makefile] - Failed to install Poetry. Exiting.\n"; \
			exit 1; \
		fi; \
	else \
		printf "[Makefile] - Poetry is already installed.\n"; \
	fi

.PHONY: poetry-remove
poetry-remove:
	@if command -v poetry > /dev/null 2>&1; then \
		printf "[Makefile] - Uninstalling Poetry...\n"; \
		curl -sSL https://install.python-poetry.org | $(PYTHON) - --uninstall || \
		{ brew list poetry > /dev/null 2>&1 && brew uninstall poetry || printf "[Makefile] - Poetry was not installed with Homebrew.\n"; }; \
	else \
		printf "[Makefile] - Poetry is not installed.\n"; \
	fi
	@printf "[Makefile] - Poetry removal complete.\n\n"

#* Installation
.PHONY: poetry-install
poetry-install:
	@$(POETRY) config virtualenvs.in-project true
	@$(POETRY) config virtualenvs.create true
	@$(POETRY) config installer.parallel true
	@$(POETRY) config cache-dir $(HOME)/.cache/pypoetry
	@$(POETRY) lock -n && $(POETRY) export --without-hashes --output=requirements.txt
	@$(POETRY) install
	@mkdir -p src/doc_ingestion_pipeline/experiments/.pkg
	@cp requirements.txt src/doc_ingestion_pipeline/experiments/.pkg/
	@printf "[Makefile] - Poetry installation and setup complete.\n\n"

.PHONY: poetry-update
poetry-update:
	@$(POETRY) update
	@printf "[Makefile] - Poetry updated.\n\n"

.PHONY: pre-commit-install
pre-commit-install:
	@sudo apt install python3.10-distutils
	@$(POETRY) add pre-commit=
	@$(POETRY) run pre-commit install
	@printf "[Makefile] - Pre-commit hooks installed.\n\n"

.PHONY: pre-commit-update
pre-commit-update:
	@$(POETRY) run pre-commit autoupdate
	@printf "[Makefile] - Pre-commit hooks updated.\n\n"

#* Miniconda installation (if needed)
.PHONY: miniconda-install
miniconda-install:
	@printf "[Makefile] - Checking if Miniconda is installed...\n"
	@if ! command -v conda > /dev/null 2>&1; then \
		printf "[Makefile] - Miniconda not found. Installing Miniconda...\n"; \
		if [ "$$(uname -m)" = "arm64" ]; then \
			sudo curl -o /Miniconda3-latest-MacOSX-arm64.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh; \
			sudo bash /Miniconda3-latest-MacOSX-arm64.sh -b -p $$HOME/miniconda3; \
			sudo rm /Miniconda3-latest-MacOSX-arm64.sh; \
		else \
			sudo curl -o /Miniconda3-latest-MacOSX-x86_64.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh; \
			sudo bash /Miniconda3-latest-MacOSX-x86_64.sh -b -p $$HOME/miniconda3; \
			sudo rm /Miniconda3-latest-MacOSX-x86_64.sh; \
		fi; \
		$$HOME/miniconda3/bin/conda init; \
		printf "[Makefile] - Miniconda installation complete.\n"; \
	else \
		printf "[Makefile] - Miniconda is already installed!\n"; \
	fi
	@printf "[Makefile] - Configuring Conda to not 'auto-activate' the base environment...\n"
	@printf "[Makefile] - If you want to activate your conda environment back just run 'conda activate base'.\n"
	@export PATH=$$HOME/miniconda3/bin:$$PATH && conda config --set auto_activate_base false
	@printf "[Makefile] - Conda configuration updated.\n"

#* Project setup
.PHONY: init
init: create-venv poetry-download poetry-install pre-commit-install gcloud-auth activate-venv
	@printf "[Makefile] - ***** Project setup complete *****\n"

#* Project setup
.PHONY: refresh
refresh: gcloud-auth activate-venv
	@printf "[Makefile] - ***** Project auth login complete *****\n"

#* Formatters
.PHONY: codestyle
codestyle:
	@$(POETRY) run pyupgrade --exit-zero-even-if-changed --py39-plus $(shell find . -name "*.py")
	@$(POETRY) run isort --settings-path pyproject.toml src
	@$(POETRY) run black --config pyproject.toml src
	@printf "[Makefile] - Code style formatting complete.\n\n"

.PHONY: check-codestyle
check-codestyle:
	@$(POETRY) run isort --diff --check-only --settings-path pyproject.toml src
	@$(POETRY) run black --diff --check --config pyproject.toml src
	@$(POETRY) run darglint --verbosity 2 src tests
	@printf "[Makefile] - Code style check complete.\n\n"

.PHONY: formatting
formatting: codestyle check-codestyle
	@printf "[Makefile] - ***** Formatting complete *****\n"

#* Linting
.PHONY: test
test:
	@mkdir -p assets/images
	@PYTHONPATH=$(PYTHONPATH) $(POETRY) run pytest -c pyproject.toml --cov-report=html --cov=src tests/
	@$(POETRY) run coverage-badge -o assets/images/coverage.svg -f
	@printf "[Makefile] - Tests and coverage complete.\n\n"

.PHONY: check
check:
	@$(POETRY) check
	@printf "[Makefile] - Poetry check complete.\n\n"

.PHONY: check-safety
check-safety:
	@$(POETRY) run safety check --full-report
	@printf "[Makefile] - Safety check complete.\n\n"

.PHONY: check-bandit
check-bandit:
	@$(POETRY) run bandit -vv -ll --recursive src
	@printf "[Makefile] - Bandit check complete.\n\n"

.PHONY: env-check
env-check: check check-bandit check-safety
	@printf "[Makefile] - ***** Environment check complete *****\n"

.PHONY: update-dev-deps
update-dev-deps:
	@$(POETRY) add --group dev_latest darglint@latest "isort[colors]@latest" pydocstyle@latest pylint@latest pytest@latest coverage@latest coverage-badge@latest pytest-html@latest pytest-cov@latest
	@$(POETRY) add --group dev_latest --allow-prereleases black@latest
	@printf "[Makefile] - Development dependencies updated.\n\n"

#* Docker build and push
.PHONY: docker-build
docker-build:
	@printf "[Makefile] - Building Docker image %s:%s-%s...\n" "$(IMAGE)" "$(VERSION)" "$(TAG)"
	@docker build -t "$(ARTIFACT_REGISTRY_URI)/$(IMAGE):$(VERSION)-$(TAG)" . --no-cache
	@printf "[Makefile] - Docker image build complete.\n"

.PHONY: docker-push
docker-push:
	@printf "[Makefile] - Pushing Docker image %s:%s-%s to Artifact Registry...\n" "$(IMAGE)" "$(VERSION)" "$(TAG)"
	@gcloud auth configure-docker us-central1-docker.pkg.dev
	@docker push $(ARTIFACT_REGISTRY_URI)/$(IMAGE):$(VERSION)-$(TAG)
	@printf "[Makefile] - Docker image push complete.\n"

.PHONY: docker-remove
docker-remove:
	@printf "[Makefile] - Checking if Docker is installed...\n"
	@if ! command -v docker > /dev/null 2>&1; then \
		printf "[Makefile] - Docker is not installed. Please install Docker and try again.\n"; \
		exit 1; \
	fi
	@printf "[Makefile] - Removing Docker image %s:%s-%s ...\n" "$(IMAGE)" "$(VERSION)" "$(TAG)"
	@docker rmi -f $(IMAGE):$(VERSION)-$(TAG)
	@printf "[Makefile] - Docker image removal complete.\n"

#* Docker system prune (optional)
.PHONY: docker-clean
docker-clean:
	@printf "[Makefile] - Running Docker system prune to clean up unused Docker objects...\n"
	@docker system prune -f
	@printf "[Makefile] - Docker system prune complete.\n"

#* Build and Distribution
.PHONY: build-wheel
build-wheel:
	@$(POETRY) install
	@$(PYTHON) setup.py sdist --formats=zip bdist_wheel
	@printf "[Makefile] - Build complete. '.tar.gz', '.zip', and '.whl' files generated in 'dist/' directory.\n\n"

.PHONY: clean-build
clean-build:
	@rm -rf build/ dist/ *.egg-info
	@printf "[Makefile] - Build artifacts cleaned.\n\n"

.PHONY: clean-dist
clean-dist: clean-build
	@rm -rf dist/
	@printf "[Makefile] - Distribution artifacts cleaned.\n\n"

.PHONY: clean-all
clean-all: cleanup clean-dist
	@printf "[Makefile] - All artifacts cleaned.\n\n"

#* Cleaning
.PHONY: pycache-remove
pycache-remove:
	@find . -type f \( -name "__pycache__" -o -name "*.pyc" -o -name "*.pyo" \) -print0 | xargs -0 rm -rf

.PHONY: dsstore-remove
dsstore-remove:
	@find . -name ".DS_Store" -print0 | xargs -0 rm -rf

.PHONY: mypycache-remove
mypycache-remove:
	@find . -name ".mypy_cache" -print0 | xargs -0 rm -rf

.PHONY: ipynbcheckpoints-remove
ipynbcheckpoints-remove:
	@find . -name ".ipynb_checkpoints" -print0 | xargs -0 rm -rf

.PHONY: pytestcache-remove
pytestcache-remove:
	@find . -name ".pytest_cache" -print0 | xargs -0 rm -rf

.PHONY: build-remove
build-remove:
	@rm -rf build/

.PHONY: cleanup
cleanup: pycache-remove dsstore-remove mypycache-remove ipynbcheckpoints-remove pytestcache-remove
	@printf "[Makefile] - ***** Cleanup environment complete *****\n"

#* Start Airflow
.PHONY: start-airflow
start-airflow:
	@printf "[Makefile] - Setting up Airflow home to 'src/doc_ingestion_pipeline'.\n"
	@AIRFLOW_HOME=$(shell pwd)/src/doc_ingestion_pipeline \
		$(POETRY) run airflow db migrate
	@printf "\n[Makefile] - Starting Airflow...\n"
	@AIRFLOW_HOME=$(shell pwd)/src/doc_ingestion_pipeline \
		$(POETRY) run airflow standalone

#* Start JupyterLab
.PHONY: start-jupyterlab
start-jupyterlab:
	@printf "[Makefile] - Starting JupyterLab...\n"
	@chmod +x src/doc_ingestion_pipeline/experiments/start_jupyterlab.sh
	@if [ ! -f src/doc_ingestion_pipeline/experiments/start_jupyterlab.sh ]; then \
		printf "[Makefile] - start_jupyterlab.sh not found!\n"; \
		exit 1; \
	fi
	@src/doc_ingestion_pipeline/experiments/start_jupyterlab.sh

# Set GH Workflows Variables
.PHONY: setup-env
setup-env:
	@printf "[Makefile] - Setting up environment variables...\n"
	@LOCAL_DAGS_PATH="src/doc_ingestion_pipeline/dags"; \
	COMPOSER_BUCKET="gs://doc_ingestion_pipeline"; \
	DOCKER_IMAGE_TAG="$(IMAGE):$(VERSION)-$${SANITIZED_TAG}"; \
	DOCKER_FILE_TAG="docker_version.txt"; \
	ARTIFACT_REGISTRY_URI="us-central1-docker.pkg.dev/doc_ingestion_pipeline-dev"; \
	printf "LOCAL_DAGS_PATH=%s\n" "$$LOCAL_DAGS_PATH"; \
	printf "COMPOSER_BUCKET=%s\n" "$$COMPOSER_BUCKET"; \
	printf "DOCKER_IMAGE_TAG=%s\n" "$$DOCKER_IMAGE_TAG"; \
	printf "DOCKER_FILE_TAG=%s\n" "$$DOCKER_FILE_TAG"; \
	printf "ARTIFACT_REGISTRY_URI=%s\n" "$$ARTIFACT_REGISTRY_URI"; \
	printf "LOCAL_DAGS_PATH=%s\n" "$$LOCAL_DAGS_PATH" >> $${GITHUB_ENV}; \
	printf "COMPOSER_BUCKET=%s\n" "$$COMPOSER_BUCKET" >> $${GITHUB_ENV}; \
	printf "DOCKER_IMAGE_TAG=%s\n" "$$DOCKER_IMAGE_TAG" >> $${GITHUB_ENV}; \
	printf "DOCKER_FILE_TAG=%s\n" "$$DOCKER_FILE_TAG" >> $${GITHUB_ENV}; \
	printf "ARTIFACT_REGISTRY_URI=%s\n" "$$ARTIFACT_REGISTRY_URI" >> $${GITHUB_ENV}; \
	printf "%s\n" "$$DOCKER_IMAGE_TAG" > "$$DOCKER_FILE_TAG"

#* Sync files to Composer bucket
.PHONY: sync-files
sync-files:
	@printf "[Makefile] - Syncing files to Composer bucket...\n"
	# Sync doc_ingestion_pipeline folder
	gsutil -m rsync -x 'endpoints/.*|experiments/.*|dags/.*dag\.py' -r src/doc_ingestion_pipeline $(COMPOSER_BUCKET)/dags/doc_ingestion_pipeline

	# Copy __init__.py and docker_version.txt
	gsutil cp src/__init__.py $(COMPOSER_BUCKET)/__init__.py
	gsutil cp $(DOCKER_FILE_TAG) $(COMPOSER_BUCKET)/dags/$(DOCKER_FILE_TAG)

	# Copy setup.py
	gsutil cp setup.py $(COMPOSER_BUCKET)/dags/setup.py

	# Sync .py files from the LOCAL_DAGS_PATH
	gsutil -m cp -r $(LOCAL_DAGS_PATH)/*.py $(COMPOSER_BUCKET)/dags/

	@printf "[Makefile] - File sync complete.\n\n"

#* Build and Distribution
.PHONY: poetry-build
poetry-build:
	@printf "[Makefile] - Building source distribution and wheel using Poetry...\n"
	@poetry build
	@printf "[Makefile] - Build complete. '.tar.gz' and '.whl' files generated in 'dist/' directory.\n\n"

.PHONY: install
install:
	@printf "[Makefile] - Installing package using Poetry...\n"
	@poetry install --no-root
	@printf "[Makefile] - Package installed successfully.\n\n"

.PHONY: install-editable
install-editable:
	@printf "[Makefile] - Installing package in editable mode using Poetry...\n"
	@poetry install --editable
	@printf "[Makefile] - Package installed in editable mode successfully.\n\n"

#* Create Artifact Registry repositories if they don't exist
.PHONY: create-repositories
create-repositories:
	@printf "[Makefile] - Checking if Artifact Registry repositories exist and creating them if not...\n"
	gcloud artifacts repositories describe promptregistry \
		--location=us-central1 || \
		gcloud artifacts repositories create promptregistry \
		--repository-format=python \
		--location=us-central1 \
		--description="Repository for PromptRegistry Python packages"

	gcloud artifacts repositories describe mestring \
		--location=us-central1 || \
		gcloud artifacts repositories create mestring \
		--repository-format=python \
		--location=us-central1 \
		--description="Repository for Mestring Python packages"

#* Build and publish wheels
.PHONY: build-publish-wheels
build-publish-wheels:
	@printf "[Makefile] - Starting build and publish process for PromptRegistry...\n"
	@bash $(WHEEL_PATH)/build_publish.sh "PromptRegistry"
	@printf "[Makefile] - Completed build and publish for PromptRegistry.\n\n"

	@printf "[Makefile] - Starting build and publish process for Mestring...\n"
	@bash $(WHEEL_PATH)/build_publish.sh "Mestring"
	@printf "[Makefile] - Completed build and publish for Mestring.\n\n"

#* Pull wheels from Artifact Registry
.PHONY: pull-wheels
pull-wheels:
	@printf "[Makefile] - Pulling .whl files from Artifact Registry...\n"
	mkdir -p tmp/wheels
	gcloud artifacts repositories packages download \
		--location=us-central1 \
		--repository=my-repo \
		--package=promptregistry \
		--output-directory=tmp/wheels
	gcloud artifacts repositories packages download \
		--location=us-central1 \
		--repository=mestring \
		--package=mestring \
		--output-directory=tmp/wheels
	@printf "[Makefile] - .whl files downloaded to tmp/wheels.\n\n"

.PHONY: clean-tmp
clean-tmp:
	@rm -rf tmp/wheels
	@printf "[Makefile] - Temp folder cleaned.\n\n"

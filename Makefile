PRE_COMMIT_VERSION ?= 4.3.0

.PHONY: init reinit check docs launch clean config

init:
	@test -d .venv || python3 -m venv .venv
	.venv/bin/python -m pip install "pre-commit==$(PRE_COMMIT_VERSION)"
	.venv/bin/pre-commit install

reinit:
	rm -rf .venv
	$(MAKE) init

check:
	.venv/bin/pre-commit run --all-files

BACKUP_TIMESTAMP := $(shell date +%Y-%m-%dT%H:%M:%S%z)

backup-database:
	mkdir -p ./backups
	docker compose run -e BACKUP_TIMESTAMP=$(BACKUP_TIMESTAMP) --rm backup-database

backup-file-storage:
	mkdir -p ./backups
	docker compose run -e BACKUP_TIMESTAMP=$(BACKUP_TIMESTAMP) --rm backup-file-storage

backup: backup-database backup-file-storage

restore-database:
	docker compose stop app
	docker compose run --rm restore-database
	docker compose start app

restore-file-storage:
	docker compose stop app
	docker compose run --rm restore-file-storage
	docker compose start app

restore:
	docker compose stop app
	docker compose run --rm restore-database
	docker compose run --rm restore-file-storage
	docker compose start app

docs:
	mkdir -p ./docs
	docker compose run --rm compose-docs > docs/environment-variables.md

COMPOSE_CMD = docker compose -f docker-compose.yml -f overlays/traefik-dashboard/docker-compose.yml -f overlays/monitoring/docker-compose.yml -f overlays/glowroot/docker-compose.yml

launch:
	$(COMPOSE_CMD) up $(COMPOSE_OPTS)

clean:
	$(COMPOSE_CMD) down --remove-orphans --volumes

config:
	@$(COMPOSE_CMD) config

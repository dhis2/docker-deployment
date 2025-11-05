PRE_COMMIT_VERSION ?= 4.3.0

.PHONY: init playwright test reinit check backup-database backup-file-storage backup restore-database restore-file-storage restore docs launch clean config get-backup-timestamp

init:
	@test -d .venv || python3 -m venv .venv
	.venv/bin/python -m pip install "pre-commit==$(PRE_COMMIT_VERSION)"
	.venv/bin/pre-commit install

playwright: init
	.venv/bin/python -m pip install playwright pytest pytest-playwright pytest-order requests
	.venv/bin/playwright install

test: playwright
	DEBUG=pw:api .venv/bin/pytest --capture=no --exitfirst

test-ui: playwright
	DEBUG=pw:api .venv/bin/pytest --headed --capture=no --exitfirst

reinit:
	rm -rf .venv
	$(MAKE) init

install-loki-driver:
	docker plugin ls --format '{{.Name}}' | grep -q 'loki:latest' || ./scripts/install-loki-driver.sh
	docker plugin ls

check:
	.venv/bin/pre-commit run --all-files

BACKUP_TIMESTAMP ?= $(shell date -u +%Y-%m-%d_%H-%M-%S_%Z)

get-backup-timestamp:
	@echo $(BACKUP_TIMESTAMP)

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

launch: install-loki-driver
	$(COMPOSE_CMD) up $(COMPOSE_OPTS)

clean:
	$(COMPOSE_CMD) down --remove-orphans --volumes

config:
	@$(COMPOSE_CMD) config

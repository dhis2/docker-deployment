.PHONY: install lint update help venv

help:
	@echo "install - Set up development environment"
	@echo "lint    - Run all linters"
	@echo "update  - Update linter versions"

venv:
	@test -d .venv || python3 -m venv .venv

install:
	$(MAKE) venv
	. .venv/bin/activate && pip install -U pip pre-commit
	npm install -g dclint
	.venv/bin/pre-commit install

lint:
	.venv/bin/pre-commit run --all-files

update:
	.venv/bin/pre-commit autoupdate
	npm update -g dclint

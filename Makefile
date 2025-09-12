PYTHON ?= python3.11
PRE_COMMIT_VERSION ?= 4.3.0

.PHONY: install lint update help venv

venv:
	@test -d .venv || $(PYTHON) -m venv .venv

install:
	$(MAKE) venv
	.venv/bin/python -m pip install --upgrade pip
	.venv/bin/python -m pip install "pre-commit==$(PRE_COMMIT_VERSION)"
	npm install -g dclint
	.venv/bin/pre-commit install

lint:
	.venv/bin/pre-commit run --all-files

update:
	.venv/bin/pre-commit autoupdate
	npm update -g dclint

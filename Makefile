PRE_COMMIT_VERSION ?= 4.3.0

VENV := .venv
PIP := $(VENV)/bin/python -m pip
PRE_COMMIT := $(VENV)/bin/pre-commit

.PHONY: init lint check clean update

init:
	@test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install "pre-commit==$(PRE_COMMIT_VERSION)"
	$(PRE_COMMIT) install

reinit:
	rm -rf $(VENV)
	$(MAKE) init

check:
	$(PRE_COMMIT) run --all-files

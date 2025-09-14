PRE_COMMIT_VERSION ?= 4.3.0

VENV := .venv
PRE_COMMIT := $(VENV)/bin/pre-commit

.PHONY: init reinit check

init:
	@test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/python -m pip install "pre-commit==$(PRE_COMMIT_VERSION)"
	$(PRE_COMMIT) install

reinit:
	rm -rf $(VENV)
	$(MAKE) init

check:
	$(PRE_COMMIT) run --all-files

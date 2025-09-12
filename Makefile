PYTHON ?= python3
PRE_COMMIT_VERSION ?= 4.3.0

VENV := .venv
PIP := $(VENV)/bin/python -m pip
PRE_COMMIT := $(VENV)/bin/pre-commit

.DEFAULT_GOAL := check
.PHONY: init lint check clean update

$(VENV):
	@test -d $(VENV) || $(PYTHON) -m venv $(VENV)

$(PRE_COMMIT): $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install "pre-commit==$(PRE_COMMIT_VERSION)"

.git/hooks/pre-commit: $(PRE_COMMIT)
	$(PRE_COMMIT) install
	@touch $@

init: .git/hooks/pre-commit

lint: init
	$(PRE_COMMIT) run --all-files

check: lint

update:
	$(PRE_COMMIT) autoupdate

clean:
	rm -rf $(VENV)

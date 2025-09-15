PRE_COMMIT_VERSION ?= 4.3.0

.PHONY: init reinit check

init:
	@test -d .venv || python3 -m venv .venv
	.venv/bin/python -m pip install "pre-commit==$(PRE_COMMIT_VERSION)"
	.venv/bin/pre-commit install

reinit:
	rm -rf .venv
	$(MAKE) init

check:
	.venv/bin/pre-commit run --all-files

# bootstrap, firewall and harden come from the sre.server collection in dhis2-sre/server-baseline, so
# the hardening has one implementation shared with the other projects that run DHIS2 workloads on
# plain servers.
#
# It is pinned to a tag in ../requirements.yml. Override this to install it from somewhere else and
# try a change before it is tagged, with a local clone or a branch:
#
#   make provision SERVER_BASELINE=/path/to/server-baseline
#   make provision SERVER_BASELINE=git+https://github.com/dhis2-sre/server-baseline.git,my-branch
SERVER_BASELINE ?=
GALAXY_SOURCE = $(if $(SERVER_BASELINE),$(SERVER_BASELINE),--requirements-file ../requirements.yml)

# Prepares the server: the shared baseline, then a checkout of this repository in deploy_dir. It
# starts nothing. Bringing the stacks up is `make start-*` on the host, by an operator.
provision: collections
	ansible-playbook --verbose --inventory inventory/production.ini playbooks/provision.yml --become-password-file ./.ansible_become_pass

# --force because ansible-galaxy leaves an already installed collection alone otherwise, which would
# quietly keep the previous baseline after the pin, or SERVER_BASELINE, changes.
collections:
	ansible-galaxy collection install --force $(GALAXY_SOURCE)

.PHONY: provision collections

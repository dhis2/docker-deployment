# bootstrap, firewall and harden come from dhis2-sre/server-baseline, so the hardening has one
# implementation shared with the other projects that run DHIS2 workloads on plain servers.
#
# Pinned to a commit rather than a branch, so the hardening cannot change under you between two runs
# of the same playbook. Bump it deliberately and read the diff. To try changes to the shared roles
# before pushing them, point at a local clone:
#
#   make deployment SERVER_BASELINE_URL=/path/to/server-baseline SERVER_BASELINE_REF=my-branch
SERVER_BASELINE_URL ?= https://github.com/dhis2-sre/server-baseline.git
SERVER_BASELINE_REF ?= 2626ebed03721e6423d58efed3e67816b1378e70

deployment: roles
	ansible-playbook --verbose --inventory inventory.ini site.yml --become-password-file ./.ansible_become_pass

roles:
	rm -rf external/server-baseline
	git clone --quiet --no-checkout $(SERVER_BASELINE_URL) external/server-baseline
	git -C external/server-baseline checkout --quiet $(SERVER_BASELINE_REF)
	ansible-galaxy collection install --requirements-file external/server-baseline/requirements.yml

.PHONY: deployment roles

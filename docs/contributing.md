# Contributing

For working on this deployment itself, rather than using it to run DHIS2.

## Development setup

You need Python 3.11 or later with pip, `make`, and Docker with Compose v2.

```shell
make init
```

That creates a `.venv`, installs pre-commit, and installs the git hooks. `make reinit` rebuilds the environment from scratch if it gets into a bad state.

Run the checks over the whole tree:

```shell
make check
```

Pre-commit runs on commit, but `make check` runs every hook over every file, which is what CI does. The hooks cover shellcheck and shfmt for scripts, yamllint and dclint for compose files, markdownlint and textlint for documentation, and commitizen for commit messages — so commits must follow [Conventional Commits](https://www.conventionalcommits.org/).

## Running a development instance

Same workflow as any other deployment, with local hostnames. Use `SUDO=` if your user is in the `docker` group.

```shell
GEN_LETSENCRYPT_ACME_EMAIL=dev@dhis2.org make generate-stack-envs
SUDO= COMPOSE_OPTS=-d make start-traefik
SUDO= COMPOSE_OPTS=-d make start-monitoring

APP_HOSTNAME=dhis2.127-0-0-1.nip.io PROJECT_NAME=dev make create-instance
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=dev make start-instance
```

Tear it down with `SUDO= PROJECT_NAME=dev make stop-instance`, or `SUDO= PROJECT_NAME=dev make clean-all` to destroy the volumes as well and start from nothing.

`make config` prints the fully resolved Compose configuration for an instance, which is the quickest way to see what a variable actually evaluated to after overlays are applied.

The [test environment guide](guides/test-environment.md) covers running several instances at once and pinning DHIS2 versions.

## Tests

```shell
PROJECT_NAME=dev SUDO= make test      # headless
PROJECT_NAME=dev SUDO= make test-ui   # with a visible browser
```

The Playwright suite runs against an already-running instance and covers login, user update, app installation, monitoring, profiling traces, and backup and restore. It reads `instances/<name>/.env` itself, so `PROJECT_NAME` is all it needs. Keep `SUDO=` in the environment: the backup and restore tests shell back out to `make` and pick it up from there.

The suite validates a single running instance. The lifecycle around it — provisioning, multi-instance, VPN, restore — is covered by the guides, which double as manual acceptance walkthroughs: each step has an explicit **Verify** with the result to expect.

Note that this suite tests **this deployment project**, not DHIS2. Testing DHIS2 itself with a disposable instance is the [test environment guide](guides/test-environment.md).

### When the suite fails

**It fails on the Docker socket.** The helpers call `docker ps` and `docker exec` directly, and the `SUDO` override does not reach those calls — though it does reach the `make` targets the backup and restore tests invoke. A server provisioned by `server-provisioning` deliberately keeps the operator out of the `docker` group, so the suite cannot run there without giving up that posture. Run it from a laptop or dev container where your user can talk to the Docker socket, and verify a server deployment by hand instead.

**It fails in ways that look like leftover state.** Some assertions expect a fresh instance. Reset and re-run:

```shell
SUDO= PROJECT_NAME=dev make stop-instance && PROJECT_NAME=dev SUDO= make test
```

**A test fails and you want to watch it.** `make test-ui` runs the same suite with a visible browser.

## Documentation

### Layout

```text
README.md              front door: what this is, and which guide to follow
docs/guides/           complete walkthroughs, one per audience
docs/reference/        look-it-up material, audience-agnostic
docs/contributing.md   this file
```

The split matters for keeping things maintainable. A **guide** takes one audience from nothing to a working deployment, in order, with a `Verify` step after anything that can fail; it links reference material rather than restating it. A **reference** page explains one subsystem completely, for a reader who already has something running and needs a detail. Content that would otherwise be repeated across guides belongs in reference.

The four guides target distinct audiences — production operators, small-team hosts, people evaluating DHIS2, and testers. When adding to a guide, check it is right for *that* audience: production-grade operational detail does not belong in the demo guide, and vice versa.

### Conventions

- **Verify steps.** Anything that can fail gets an explicit statement of the expected result, so a reader can tell whether to continue.
- **Accurate commands.** Every command is copy-pasteable and reflects what the code does now. If documentation and code disagree, one of them is a bug.
- **No duplication.** Link instead. The one exception is short command sequences that would be absurd to follow a link for, and those should still point at the canonical version.
- **Mermaid for diagrams**, inline in Markdown. Use `<br/>` for line breaks in labels, never `\n`.

Markdown is linted by markdownlint and textlint on commit. Line length is not enforced.

### Generated documentation

[`docs/reference/environment-variables.md`](reference/environment-variables.md) is generated from the comments in the compose files, and should not be edited by hand:

```shell
make docs
```

Document a variable by adding a `# --` comment above it in the compose file, then regenerating.

### Diagrams

The architecture diagram is [D2](https://d2lang.com/) source at [`docs/architecture.d2`](architecture.d2), using the [ELK](https://eclipse.dev/elk/) layout engine for cleaner routing of dense graphs.

Install D2:

```shell
# macOS
brew install d2

# Linux / WSL
curl -fsSL https://d2lang.com/install.sh | sh
```

Regenerate the SVG:

```shell
~/.local/bin/d2 docs/architecture.d2 docs/architecture.svg
```

> [!NOTE]
> The DHIS2 CLI is also named `d2` and shadows the diagram tool in `$PATH`. Use the full path, or add an alias: `alias d2diagram=~/.local/bin/d2`.

Commit the regenerated SVG alongside the source.

## Server provisioning

The Ansible playbook that prepares a bare server lives in [`server-provisioning/`](../server-provisioning/), with its own README. It provisions and hardens the server and optionally clones this repository; it does not start any containers. The hardening roles are shared with other DHIS2 server projects through the `sre.server` collection, pinned by tag in [`requirements.yml`](../requirements.yml).

## Getting help

Discussion happens in the DHIS2 Community of Practice, in [DHIS2 on Docker](https://community.dhis2.org/c/server-administration/docker/95).

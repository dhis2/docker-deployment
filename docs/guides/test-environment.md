# Test environment

For testing a DHIS2 version, a custom app, or a bug report: disposable instances on your own machine, on the DHIS2 version you choose, isolated from each other and cheap to throw away and rebuild.

About fifteen minutes for the first instance. Additional instances take two commands each, and several can run side by side — which is what makes this useful for comparing behaviour across versions.

## Before you start

You need:

- **Docker and Docker Compose v2**, `make` and `git`.
- **Ports 80 and 443 free.**
- **Enough RAM.** Each instance runs its own DHIS2 and PostgreSQL. Allow around 4 GB per instance; three instances on a 16 GB laptop is realistic, and on Docker Desktop you will need to raise the memory limit in *Settings → Resources*.
- **Internet access**, for container images and the OpenTelemetry Java agent each instance fetches from GitHub on first start.

No DNS setup: hostnames under `*.127-0-0-1.nip.io` resolve to your own machine automatically. Certificates are self-signed, so browsers warn and `curl` needs `-k`.

```shell
git clone https://github.com/dhis2/docker-deployment.git
cd docker-deployment
```

> [!IMPORTANT]
> Commands below include `SUDO=` — the trailing `=` is deliberate, and makes `make` run Docker without `sudo`. Drop it if your user is not in the `docker` group and you normally type `sudo docker`.

## Step 1 — One-time host setup

Once per machine, shared by every instance you create afterwards.

```shell
GEN_LETSENCRYPT_ACME_EMAIL=dev@example.com make generate-stack-envs
SUDO= COMPOSE_OPTS=-d make start-traefik
SUDO= COMPOSE_OPTS=-d make start-monitoring
docker ps
```

**Verify:** `traefik` and the monitoring containers — grafana, prometheus, loki, node-exporter, cadvisor — are `Up`, and `docker network ls` shows the shared `proxy` and `monitoring` networks.

The monitoring stack is optional for testing. Start it if you want metrics and, more usefully, all instances' logs collected in one place; skip `start-monitoring` to save a few hundred megabytes of RAM.

> [!NOTE]
> `generate-stack-envs` refuses to overwrite existing files. If you are rebuilding an environment you have used before, either keep the `stacks/*/.env` files you already have, or delete all of them **together** and recreate your instances — instance env files copy the monitoring credentials, and the two must stay in step.

## Step 2 — Create a throwaway instance

Pick a name for the instance, and a hostname under `127-0-0-1.nip.io`:

```shell
APP_HOSTNAME=test.dhis2.127-0-0-1.nip.io PROJECT_NAME=test make create-instance
```

**Verify:** `instances/test/.env` exists, along with `instances/test/dhis2/` and `instances/test/postgresql/`.

**Set the version you want to test** in `instances/test/.env`:

```dotenv
DHIS2_VERSION=43.0.0
```

Any tag published for the [`dhis2/core`](https://hub.docker.com/r/dhis2/core/tags) image works: a full version like `43.0.0`, a major version like `43` that follows the latest patch, or a development tag. `POSTGRES_VERSION` is set in the same file if you need to test against a particular PostgreSQL.

Then start it:

```shell
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=test make start-instance
```

Initialising a blank database takes a few minutes. Then:

```shell
curl -kI https://test.dhis2.127-0-0-1.nip.io/login.html
SUDO= make list-instances
```

**Verify:** `curl` returns `HTTP/2 200`, and `list-instances` shows `test` with a non-zero container count. In a browser, the hostname shows the DHIS2 login — click through the self-signed certificate warning. Log in as `admin` with `DHIS2_ADMIN_PASSWORD` from `instances/test/.env`.

Confirm you are testing what you think you are:

```shell
curl -ks https://test.dhis2.127-0-0-1.nip.io/api/system/info.json | grep -o '"version":"[^"]*"'
```

## Step 3 — Run several versions side by side

This is the point of the multi-instance model: each instance has its own database on its own network, its own credentials and its own hostname, sharing only the reverse proxy and monitoring. Comparing two versions means running both.

```shell
APP_HOSTNAME=v42.dhis2.127-0-0-1.nip.io PROJECT_NAME=v42 make create-instance
APP_HOSTNAME=v43.dhis2.127-0-0-1.nip.io PROJECT_NAME=v43 make create-instance
```

Set `DHIS2_VERSION` in each of `instances/v42/.env` and `instances/v43/.env`, then start both:

```shell
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=v42 make start-instance
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=v43 make start-instance
```

**Verify:**

```shell
docker network ls | grep -E 'v42-db|v43-db'   # one isolated db network each
ls stacks/traefik/conf.d/                      # one route file each
SUDO= make list-instances                      # both, with containers running
```

Each instance also has **distinct** generated passwords, but the **same** `DHIS2_MONITOR_*` credentials, copied from `stacks/monitoring/.env` so the one shared Prometheus can scrape all of them.

**Verify isolation** by changing something in one and confirming it does not appear in the other — rename the root organisation unit in `v42`, then look at `v43`. Nothing crosses between instances.

> [!NOTE]
> Every instance runs its own Tempo for request tracing, and all of them join the shared `monitoring` network under the same `tempo` alias, which Docker DNS round-robins. Traces from one instance can therefore land in another's Tempo. It does not affect the instances themselves, but do not rely on per-instance trace separation while more than one instance is running.

Instances start and stop independently:

```shell
SUDO= PROJECT_NAME=v42 make stop-instance
curl -kI https://v42.dhis2.127-0-0-1.nip.io/login.html   # now fails
curl -kI https://v43.dhis2.127-0-0-1.nip.io/login.html   # still 200
```

**Verify:** `v42`'s route file, Prometheus targets and `v42-db` network are gone, and it is unreachable, while `v43` is untouched. `instances/v42/.env` is kept, so `make start-instance` brings it straight back.

## Testing against known data

A blank instance is right for testing installation and upgrade behaviour. For reproducing a bug report you usually want the Sierra Leone demo database, so that your instance matches what the reporter and everyone else is looking at.

The [demo environment guide](demo-environment.md#step-3--load-the-demo-database) has the procedure. In short, for an instance named `test`:

```shell
mkdir -p backups/test
curl -L -o backups/test/demo.sql.gz \
  https://databases.dhis2.org/sierra-leone/2.43/dhis2-db-sierra-leone.sql.gz
SUDO= PROJECT_NAME=test DB_RESTORE_FILE=demo.sql.gz make restore-database
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=test make start-instance   # re-applies your admin password
```

Match the dump's version to `DHIS2_VERSION`. A dump newer than the application image can fail Flyway migration on startup.

To test an **upgrade path**, restore a dump taken on the old version, then raise `DHIS2_VERSION` and restart — DHIS2 migrates the database on startup, and that is exactly the step you want to exercise.

### Resetting an instance

The quickest way back to a known state is to destroy and recreate, which takes about a minute plus DHIS2's initialisation:

```shell
SUDO= PROJECT_NAME=test make delete-instance    # irreversible: volumes and instances/test/
APP_HOSTNAME=test.dhis2.127-0-0-1.nip.io PROJECT_NAME=test make create-instance
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=test make start-instance
```

`delete-instance` prompts for confirmation when run interactively. Note that recreating generates **new** passwords, so check `instances/test/.env` again.

To keep the instance but reload its data, restore a dump instead — [backup and restore](../reference/backup-restore.md).

## Tearing down

```shell
for n in test v42 v43; do SUDO= PROJECT_NAME=$n make stop-instance; done
SUDO= make clean-traefik
SUDO= make clean-monitoring
```

That keeps every instance's configuration and data, ready to restart. For a full wipe:

```shell
for n in test v42 v43; do SUDO= PROJECT_NAME=$n make delete-instance; done
```

## What to read next

- [Troubleshooting](../reference/troubleshooting.md) — when an instance will not come up.
- [Instance lifecycle](../reference/instance-lifecycle.md) — exactly what each `make` target changes.
- [Backup and restore](../reference/backup-restore.md) — moving data between instances.
- [Profiling and APM](../reference/profiling.md) — Glowroot and Tempo, for performance testing.
- [Contributing](../contributing.md) — if you are changing this deployment rather than testing DHIS2 with it.

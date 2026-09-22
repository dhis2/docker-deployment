# Demo environment

For trying DHIS2 out: a single instance on your own machine, pre-loaded with the Sierra Leone demo database so there is real metadata and data to explore rather than an empty shell.

About twenty minutes, most of it downloading. Nothing is exposed to the internet and nothing permanent is changed on your machine — when you are done, one command removes it all.

> [!TIP]
> If you only want to click around a DHIS2 instance, [play.dhis2.org](https://play.dhis2.org) gives you one in your browser immediately, with no installation. Follow this guide instead when you want an instance that is **yours**: one you can break, reconfigure, take offline, upgrade, or install apps into, without affecting anyone else.

## Before you start

You need:

- **Docker and Docker Compose v2** — [Docker Desktop](https://docs.docker.com/desktop/) on macOS or Windows, Docker Engine on Linux.
- **`make` and `git`.** Both are preinstalled on macOS and most Linux distributions.
- **Ports 80 and 443 free.** If you run a local web server, stop it first.
- **About 10 GB of free disk space**, and at least 4 GB of RAM available to Docker. On Docker Desktop, raise the memory limit in *Settings → Resources* if it is lower.
- **An internet connection**, for the container images and the demo database (roughly 86 MB).

No domain name and no DNS setup are needed. This guide uses [nip.io](https://nip.io), a free service whose hostnames resolve to an IP address embedded in the name — `dhis2.127-0-0-1.nip.io` resolves to `127.0.0.1`, your own machine, with nothing to configure.

Check your tools, and get the repository:

```shell
docker --version && docker compose version   # Compose v2 required
make --version

git clone https://github.com/dhis2/docker-deployment.git
cd docker-deployment
```

> [!IMPORTANT]
> Commands that start containers include SUDO=. This is not a typo and the trailing `=` matters: it tells `make` to run Docker **without** `sudo`, which is what you want on your own machine where your user can already talk to Docker. Leave `SUDO=` off if you normally type `sudo docker`.

## Step 1 — Start the reverse proxy

Once per machine. This generates configuration and starts Traefik, which gives your instance an HTTPS address.

```shell
GEN_LETSENCRYPT_ACME_EMAIL=you@example.com make generate-stack-envs
SUDO= COMPOSE_OPTS=-d make start-traefik
```

**Verify:** `docker ps` shows a `traefik` container `Up`.

The email address is never used here — Let's Encrypt cannot issue a certificate for an address on your own machine, so Traefik falls back to a self-signed one. Any valid-looking address will do.

This guide does not start the monitoring stack, because a demo does not need metrics and dashboards. Your instance still runs fine without it. You can add it any time with `SUDO= COMPOSE_OPTS=-d make start-monitoring`.

## Step 2 — Create and start the instance

```shell
APP_HOSTNAME=dhis2.127-0-0-1.nip.io PROJECT_NAME=demo make create-instance
```

**Verify:** `instances/demo/.env` exists. It holds the generated passwords for this instance, including `DHIS2_ADMIN_PASSWORD`, which you will need shortly.

Before starting, check that `DHIS2_VERSION` in that file is `43`. The demo database is published per DHIS2 version, and the two have to match — a dump from a different version can fail to migrate on startup.

```shell
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=demo make start-instance
```

This starts PostgreSQL, registers the hostname with Traefik, and starts DHIS2, which then initialises an **empty** database. That takes a few minutes; the demo data comes in the next step.

Confirm it is up before overwriting the database:

```shell
curl -kI https://dhis2.127-0-0-1.nip.io/login.html
```

**Verify:** `HTTP/2 200`. The `-k` flag tells `curl` to accept the self-signed certificate.

You could log in now, but DHIS2 would be an empty setup wizard. Carry on.

## Step 3 — Load the demo database

The Sierra Leone demo database is the dataset used throughout DHIS2 training and documentation: a full organisation unit hierarchy, data elements, programs, dashboards and several years of data.

Download it into this instance's backup directory:

```shell
mkdir -p backups/demo
curl -L -o backups/demo/dhis2-demo.sql.gz \
  https://databases.dhis2.org/sierra-leone/2.43/dhis2-db-sierra-leone.sql.gz
ls -lh backups/demo/dhis2-demo.sql.gz
```

**Verify:** the file is roughly 86 MB. If it is a few kilobytes, the download failed and you have an error page — check the URL and try again.

> [!NOTE]
> The `2.43` in that URL must match your `DHIS2_VERSION`. Browse <https://databases.dhis2.org/> for the available versions.

Restore it. This stops DHIS2, replaces the database, and starts DHIS2 again:

```shell
SUDO= PROJECT_NAME=demo DB_RESTORE_FILE=dhis2-demo.sql.gz make restore-database
```

**Verify:** the output ends with `Database restore completed successfully` and the app restarts. Loading the dump takes a few minutes.

The demo database brings its own user accounts, which have replaced the ones your instance generated. Re-apply your own admin password:

```shell
SUDO= COMPOSE_OPTS=-d PROJECT_NAME=demo make start-instance
```

**Verify:** the `update-admin-password` step completes, and `admin` now uses the `DHIS2_ADMIN_PASSWORD` from `instances/demo/.env`.

> [!TIP]
> To use the demo's own well-known credentials instead, skip that last command and log in with `admin` / `district`.

## Step 4 — Explore

Open **<https://dhis2.127-0-0-1.nip.io>** and log in as `admin`, with the password from `instances/demo/.env` (or `district` if you skipped the step above).

Your browser will warn that the certificate is not trusted. That is expected — the certificate is self-signed, because no public authority can vouch for a name that points at your own machine. Click through the warning.

**Verify:** the dashboard is **populated** — you should see charts and maps of Sierra Leone data, not an empty setup wizard. A quick check from the command line:

```shell
curl -ks -u admin:<your-password> \
  "https://dhis2.127-0-0-1.nip.io/api/organisationUnits.json?level=1&fields=name"
# -> {"organisationUnits":[{"name":"Sierra Leone",...}]}
```

Worth a look while you are in there:

- **Dashboards** — the landing page, with saved charts, maps and pivot tables.
- **Data Visualizer** and **Maps** — build your own charts and maps from the demo data.
- **Data Entry (Beta)** — enter aggregate data against a dataset and organisation unit.
- **Tracker Capture** — individual-level data: enrol a person in a program and follow them through it.
- **Maintenance** — the metadata behind all of it: data elements, indicators, organisation units, programs.
- **App Management** — install apps from the DHIS2 App Hub into your instance.

This is a real DHIS2, so nothing is off limits. Break it freely; you can reload the demo database from the dump you already downloaded, or delete the instance and start over.

## When you are finished

Stop the instance, keeping the data so you can come back to it:

```shell
SUDO= PROJECT_NAME=demo make stop-instance
```

Start it again later with `SUDO= COMPOSE_OPTS=-d PROJECT_NAME=demo make start-instance` — no need to reload the demo database.

To remove it completely, including the database:

```shell
SUDO= PROJECT_NAME=demo make delete-instance   # irreversible
SUDO= make clean-traefik
rm -f backups/demo/dhis2-demo.sql.gz
```

## What next

- **Something did not work?** See [troubleshooting](../reference/troubleshooting.md).
- **Run several instances at once**, on different DHIS2 versions — the [test environment guide](test-environment.md).
- **Host DHIS2 for other people to use** — the [simple deployment guide](simple-deployment.md) puts an instance on your own domain with a real certificate.
- **Learn DHIS2 itself** — the [DHIS2 documentation](https://docs.dhis2.org) and the [DHIS2 Academy](https://academy.dhis2.org).

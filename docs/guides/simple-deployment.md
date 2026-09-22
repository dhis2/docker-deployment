# Simple deployment

For hosting DHIS2 for a small team or a single project, on your own server, without taking on the operational machinery of a production platform.

By the end of this guide you will have one DHIS2 instance on your own domain, served over HTTPS with a certificate that browsers trust, and a backup command you have tested. It should take about half an hour, most of it waiting for DHIS2 to initialise.

What this guide leaves out, compared with [production deployment](production-deployment.md): the monitoring stack, the VPN, multiple instances, and performance tuning. You can add any of them later without redoing anything here.

> [!CAUTION]
> This deployment is not yet recommended for critical data. See [project maturity](production-deployment.md#project-maturity) for what that means in practice.

## Before you start

You need:

- **A server** — a small cloud VM is fine. Ubuntu 24.04 is what this project is tested on. DHIS2 wants at least 4 GB of RAM to be usable, and more if your database grows.
- **Root or sudo access** over SSH.
- **A domain name** you control, with an A record pointing at the server's public IP address — for example `dhis2.example.com`. This is required for a trusted certificate: Let's Encrypt has to reach your server by that name to issue one.
- **Ports 80 and 443 open** to the internet, and nothing else already listening on them.
- **An email address** for Let's Encrypt.

### Getting Docker onto the server, securely

Two options. Both end with Docker, Compose and `make` installed and this repository checked out at `/opt/dhis2`.

**Option A — use the provisioning playbook (recommended).** It installs Docker for you *and* hardens the server: a default-deny firewall, SSH and kernel hardening, and Docker user-namespace remapping. That security work is the main reason to prefer it, and it is the same playbook the production guide uses. It needs Ansible on your own machine, not on the server. Follow [step 1 of the production guide](production-deployment.md#step-1--provision-the-server), then come back here.

**Option B — install by hand.** Follow [Docker's official installation instructions](https://docs.docker.com/engine/install/ubuntu/) on the server, then:

```shell
sudo apt-get install -y make git
sudo git clone https://github.com/dhis2/docker-deployment.git /opt/dhis2
sudo chown -R "$USER" /opt/dhis2
```

If you choose Option B, you are responsible for the server's security yourself. At minimum: configure a firewall that allows only SSH, HTTP and HTTPS; disable SSH password authentication in favour of keys; and keep the system patched.

> [!NOTE]
> Leave your user **out** of the `docker` group — membership is equivalent to root. The `make` targets call Docker through `sudo` by default, so they work without it and you will be prompted for your password. That is why no command below carries the `SUDO=` override.

## Step 1 — One-time setup

On the server, in `/opt/dhis2`. This generates configuration for the shared stacks and starts the reverse proxy that handles HTTPS.

```shell
cd /opt/dhis2
GEN_LETSENCRYPT_ACME_EMAIL=you@example.com make generate-stack-envs
COMPOSE_OPTS=-d make start-traefik
```

**Verify:** `stacks/traefik/.env` and `stacks/monitoring/.env` exist, and `sudo docker ps` shows a `traefik` container `Up`.

Traefik obtains and renews your certificate automatically, redirects HTTP to HTTPS, and picks up new instances without a restart.

> [!NOTE]
> `generate-stack-envs` also writes `stacks/monitoring/.env` even though this guide does not start the monitoring stack. That file is needed regardless: the next step copies monitoring credentials out of it. You can start monitoring later with `COMPOSE_OPTS=-d make start-monitoring` — see [monitoring](../reference/monitoring.md).
>
> The command refuses to overwrite files that already exist. If you need to regenerate, delete all three `.env` files together and recreate your instances, since the credentials have to stay in step.

## Step 2 — Create your instance

`PROJECT_NAME` names the instance and is how you address it in every later command. Pick something short; `dhis2` is a reasonable choice if you only ever run one.

```shell
APP_HOSTNAME=dhis2.example.com PROJECT_NAME=dhis2 make create-instance
```

**Verify:** `instances/dhis2/.env` exists, with your hostname and generated passwords.

Open that file and note two things:

- **`DHIS2_ADMIN_PASSWORD`** — generated for you; this is your login. Save it in a password manager.
- **`DHIS2_VERSION`** — pin it to a full version such as `43.0.0` if you would rather decide when to move to a new release. Left as `43`, the image tag follows that major version.

The file contains all your credentials and is written readable only by you. Do not commit it, and do not loosen its permissions. Every variable is documented in [environment variables](../reference/environment-variables.md).

## Step 3 — Start it

```shell
COMPOSE_OPTS=-d PROJECT_NAME=dhis2 make start-instance
```

This creates an isolated network for the database, starts PostgreSQL, registers your hostname with Traefik, and starts DHIS2. The first start also fetches the OpenTelemetry Java agent from GitHub, so the server needs outbound internet access.

DHIS2 then builds its database schema, which takes a few minutes on a first run. Check on it:

```shell
curl -I https://dhis2.example.com/login.html
make list-instances
```

**Verify:**

- `curl` returns `HTTP/2 200`, with no certificate warning — a trusted Let's Encrypt certificate has been issued. On dhis2-core 43 the login page is `/login.html`.
- `list-instances` shows your instance with a non-zero container count.
- In a browser, `https://dhis2.example.com` loads the DHIS2 login page over HTTPS.
- You can log in as `admin` with the `DHIS2_ADMIN_PASSWORD` from `instances/dhis2/.env`.

If the certificate does not appear, or the site does not load, see [troubleshooting](../reference/troubleshooting.md). The most common cause is DNS not yet resolving to the server, which Let's Encrypt needs before it will issue anything.

### Secure the login

Straight away, in the DHIS2 interface:

1. Change the `admin` password, or better, create your own named superuser account and disable `admin`.
2. Create accounts for your users with appropriate roles rather than sharing one login.

The instance is on the public internet from the moment it starts, so do this before you walk away from it.

## Step 4 — Set up backups

This is the part that is tempting to skip and genuinely should not be. It is one command:

```shell
PROJECT_NAME=dhis2 make backup
```

**Verify:** two non-empty files appear in `backups/dhis2/` — one database dump, one file storage archive.

Then make it routine. Add a cron entry on the server:

```shell
sudo crontab -e
```

```cron
# Back up DHIS2 every night at 02:30
30 2 * * * cd /opt/dhis2 && PROJECT_NAME=dhis2 make backup >> /var/log/dhis2-backup.log 2>&1
```

Two things to add beyond that:

- **Copy backups off the server.** A backup on the same disk as the database does not survive losing that disk. Sync `backups/` to object storage or another machine.
- **Test a restore at least once.** An untested backup is a guess. [Backup and restore](../reference/backup-restore.md) has the restore commands, and the [test environment guide](test-environment.md) shows how to stand up a throwaway instance to practise on, rather than experimenting on the instance your team is using.

Old backups are not pruned automatically; the directory will grow until you deal with it.

## Everyday operations

```shell
# How is it doing?
make list-instances
sudo docker ps

# Read the logs
sudo docker compose --project-name dhis2 --env-file instances/dhis2/.env logs -f app

# Stop it (keeps all data and configuration)
PROJECT_NAME=dhis2 make stop-instance

# Start it again
COMPOSE_OPTS=-d PROJECT_NAME=dhis2 make start-instance
```

### Changing a setting

Configuration lives in `instances/dhis2/`: `.env` for versions and credentials, `dhis2/dhis.conf` for DHIS2 itself, `postgresql/conf.d/` for the database. Edit, then restart the instance for the change to take effect:

```shell
PROJECT_NAME=dhis2 make stop-instance
COMPOSE_OPTS=-d PROJECT_NAME=dhis2 make start-instance
```

### Updating DHIS2

**Back up first**, then change `DHIS2_VERSION` in `instances/dhis2/.env` and restart as above. DHIS2 migrates its database on startup, and that migration is not reversible — if it goes wrong, restoring your backup is the way back. Read the release notes for the version you are moving to, and do not skip major versions.

## Growing out of this setup

Move to the [production deployment guide](production-deployment.md) when you start to want:

- **Metrics, logs and dashboards** — the monitoring stack, reachable over a VPN.
- **More than one instance** — a training or staging instance alongside the live one, which this deployment handles natively.
- **Performance tuning** — PostgreSQL and DHIS2 settings matched to your hardware and data volume.

Nothing here has to be undone. The production guide adds stacks alongside what you already have.

## What to read next

- [Backup and restore](../reference/backup-restore.md) — restore procedures in full.
- [Instance lifecycle](../reference/instance-lifecycle.md) — every `make` target and what it changes.
- [TLS certificates](../reference/tls.md) — how certificates are issued and renewed.
- [Troubleshooting](../reference/troubleshooting.md) — when something does not come up.

# Production deployment

For teams running DHIS2 as a service for an organisation, on infrastructure they are responsible for maintaining.

By the end of this guide you will have a hardened Ubuntu server running one or more DHIS2 instances on real domain names with trusted HTTPS certificates, metrics and logs collected for every instance, administrative interfaces reachable only over a VPN, and a working backup and restore procedure you have tested.

This is the longest path, because it sets up the operational machinery that the other guides deliberately skip. Budget around two hours for a first run, most of it spent waiting for the server to provision and for DHIS2 to initialise.

## Project maturity

> [!CAUTION]
> **Not yet recommended for production or critical data.**
>
> This project is available for public testing and evaluation, but it remains immature. The implementation has been designed to meet production standards, however it needs additional testing, stabilization, and a small set of features before we can recommend it for critical data.

Read this before committing an organisation's data to it. The limitations, in the order they are likely to affect you:

- **Overall maturity is the main one.** More real-world testing and validation are required. This is what the project needs from the community, and reporting what you find is a genuine contribution.
- **Tuning is per deployment and not done for you.** PostgreSQL, DHIS2 and container resource allocation all need matching to your hardware and data volume. See [PostgreSQL configuration](../reference/postgresql.md) and [tuning](#tuning).
- **No container resource limits**, so instances sharing a host can starve each other.
- **Direct database access and advanced operations require technical knowledge.** There is no administrative interface for them.
- **Backups are local and manual.** `make backup` writes to the host's own disk; scheduling it and copying the files off the host are yours to arrange, as covered in [step 6](#step-6--set-up-and-test-backups).
- **No alerting.** Metrics and logs are collected, but nothing notifies you when something breaks.
- **Single host, no high availability.** See [deliberate limits](../reference/architecture.md#deliberate-limits).

With continued development, testing and configuration, the project is intended to meet production requirements. If you deploy it, please report what you find in [DHIS2 on Docker](https://community.dhis2.org/c/server-administration/docker/95).

## Before you start

You need:

- **A dedicated host** running Ubuntu 24.04 — a VM or bare metal, reachable over SSH with a sudo-capable user (`ubuntu` by default). Nothing else should be competing for ports 80 and 443.
- **Ansible on your own machine**, plus this repository checked out locally, to run the provisioning playbook.
- **Network access to GitHub** from your machine: provisioning installs the pinned `sre.server` baseline collection with `ansible-galaxy` before it touches the server.
- **A domain name**, with DNS you can edit. See [DNS and hostnames](#dns-and-hostnames) below.
- **An email address** for Let's Encrypt registration.
- **Inbound firewall rules** at your cloud provider allowing TCP 22, 80 and 443, plus UDP 51820 for WireGuard.

### DNS and hostnames

Each instance needs its own hostname, resolving publicly to the server's IP address. Three ways to arrange that:

- **A wildcard record** — `*.example.com` pointing at the server. Every instance then gets a subdomain (`prod.example.com`, `dev.example.com`) with no further DNS work. This is the most convenient option.
- **A namespaced wildcard** — an A record for `dhis2.example.com` plus a wildcard `*.dhis2.example.com`. Host your main instance at `dhis2.example.com` and others at `dev.dhis2.example.com`, `test.dhis2.example.com`. Note that a wildcard does **not** match the bare subdomain it is rooted at, so the explicit A record is required alongside it.
- **Individual A records**, one per instance.

> [!NOTE]
> [nip.io](https://nip.io) can substitute for DNS if you want to validate the deployment before your domain is ready. Derive the hostname from the server's **public** IP — a server at `203.0.113.10` becomes `dhis2.203-0-113-10.nip.io` — and Let's Encrypt can still issue a trusted certificate, because the name resolves publicly. Loopback names like `dhis2.127-0-0-1.nip.io` will **not** get a trusted certificate, since Let's Encrypt cannot reach a loopback address; those are for the [demo](demo-environment.md) and [test](test-environment.md) guides.

## Step 1 — Provision the server

Run this from your own machine, in the `server-provisioning/` directory of your local checkout. It installs Docker and Compose, applies a default-deny firewall, hardens SSH, the kernel and Docker, and clones this repository onto the server.

Describe your host in the inventory:

```shell
cd server-provisioning
cat > inventory/production.ini <<'EOF'
[servers]
dhis2-prod

[servers:vars]
ansible_host=203.0.113.10        # your server's public IP or DNS name
ansible_user=ubuntu
#ansible_ssh_private_key_file=~/.ssh/id_dhis2
EOF
```

Give Ansible access, then run it:

```shell
ssh-copy-id ubuntu@203.0.113.10
printf '%s' 'YOUR_SUDO_PASSWORD' > ./.ansible_become_pass   # gitignored
make provision
```

**Verify:** `ansible-galaxy` installs the pinned `sre.server` collection into a gitignored `collections/` directory, and the play finishes with `failed=0`. Then, on the server:

```shell
ssh ubuntu@203.0.113.10
docker --version && docker compose version   # both present
ls /opt/dhis2/Makefile                        # repository checked out
```

The deploy directory is pinned to `/opt/dhis2` in the playbook and cannot be overridden from `group_vars`. **Everything from here on runs on the server, in `/opt/dhis2`.**

Defaults can be adjusted in `inventory/group_vars/all.yml` — a dedicated operator account, a different repository branch. The file has to sit next to the inventory: Ansible reads `group_vars` adjacent to the inventory or the playbook and silently ignores it anywhere else. The defaults match this guide, so you can skip it entirely. See [server-provisioning/README.md](../../server-provisioning/README.md) for the full variable list.

> [!NOTE]
> Provisioning deliberately leaves your operator account **out** of the `docker` group, which is root-equivalent. Instead `make` calls Docker through `sudo`, which is explicit and logged, so expect a sudo password prompt when starting containers. This is why production commands below carry no `SUDO=` override.

## Step 2 — Set up the shared stacks

Once per host. This generates the configuration for Traefik and monitoring, then starts both. They are shared by every instance on the host, so you never repeat this step.

```shell
cd /opt/dhis2
GEN_LETSENCRYPT_ACME_EMAIL=ops@example.com make generate-stack-envs
```

**Verify:** `stacks/traefik/.env`, `stacks/monitoring/.env` and `overlays/wireguard/.env` are created, containing generated passwords. Keep these — the Grafana admin password lives in `stacks/monitoring/.env`, and `create-instance` copies the monitoring credentials out of it so the shared Prometheus can scrape every instance.

> [!IMPORTANT]
> On a first pass, point Traefik at the Let's Encrypt **staging** CA. Its certificates are untrusted, so browsers will warn, but its rate limits are far higher — and the production limits are low enough that a few failed attempts can lock you out of issuing certificates for days. Set this in `stacks/traefik/.env`:
>
> ```dotenv
> LETSENCRYPT_ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory
> ```
>
> Once the whole guide works end to end, set it back to `https://acme-v02.api.letsencrypt.org/directory` and re-run `make start-traefik` to get trusted certificates. See [TLS certificates](../reference/tls.md).

Start both stacks, detached:

```shell
COMPOSE_OPTS=-d make start-traefik
COMPOSE_OPTS=-d make start-monitoring
sudo docker ps
```

**Verify:** `traefik` and the monitoring containers — grafana, prometheus, loki, node-exporter, cadvisor — are all `Up`.

Traefik watches `stacks/traefik/conf.d/` for route changes and Prometheus watches `stacks/monitoring/targets/` for scrape targets, both reloading within about a second. Neither needs restarting when you add or remove an instance.

Grafana is **not** published to the internet. It becomes reachable at `https://grafana.internal` once the VPN is up in [step 5](#step-5--put-admin-interfaces-behind-the-vpn).

## Step 3 — Create an instance

`PROJECT_NAME` is a short identifier — `prod`, `dev`, `test` — used as the Compose project name. It must be unique on the host, and it is how every later command addresses this instance.

```shell
APP_HOSTNAME=dhis2.example.com PROJECT_NAME=prod make create-instance
```

**Verify:** `instances/prod/.env` exists, containing your hostname and freshly generated passwords, and the per-instance DHIS2 and PostgreSQL configuration has been copied to `instances/prod/dhis2/` and `instances/prod/postgresql/`.

Now **review that env file before starting anything**. In particular:

- **`DHIS2_ADMIN_PASSWORD`** — generated for you. This is how you will log in; note it somewhere safe.
- **`DHIS2_VERSION`** — pin this to the exact version you intend to run in production, for example `43.0.0`, rather than leaving it on a major-version tag that moves under you.
- **`POSTGRES_VERSION`** — likewise.

Every variable is documented in [environment variables](../reference/environment-variables.md). Because the file holds credentials, `create-instance` writes it `0600`, readable only by its owner.

> [!NOTE]
> `create-instance` refuses to overwrite an existing instance. To start over, use `PROJECT_NAME=<name> make delete-instance` — which destroys that instance's data irreversibly — and create it again.

## Step 4 — Start it

```shell
COMPOSE_OPTS=-d PROJECT_NAME=prod make start-instance
```

This creates a `prod-db` network, starts PostgreSQL and waits for it to become healthy, writes the Traefik route and the two Prometheus target files, and then starts DHIS2 along with the profiling and Glowroot containers. The Loki log driver plugin is installed if it is missing. The first start needs GitHub access, to fetch the OpenTelemetry Java agent.

**Verify:** the route file `stacks/traefik/conf.d/prod.yml` and the target files `stacks/monitoring/targets/dhis2/prod.json` and `stacks/monitoring/targets/postgres/prod.json` have been written, and `sudo docker ps` shows the app, database, `postgres-exporter` and `tempo` containers for the instance.

First-run initialisation on a blank database takes a few minutes — DHIS2 is creating its schema. Health checks are not enforced for the first 120 seconds. Then:

```shell
curl -I https://dhis2.example.com/login.html
make list-instances
```

**Verify:**

- `curl` returns `HTTP/2 200`. On dhis2-core 43 the login page is `/login.html`.
- `list-instances` shows `prod`, its hostname, and a non-zero container count.
- In a browser, `https://dhis2.example.com` shows the DHIS2 login page. On the production ACME CA the certificate is trusted; on staging the browser warns, and the issuer reads *Let's Encrypt (STAGING)* — that is the expected result at this stage.
- You can log in as `admin` with the `DHIS2_ADMIN_PASSWORD` from `instances/prod/.env`.

If the instance does not come up, see [troubleshooting](../reference/troubleshooting.md).

**Change the admin password** through the DHIS2 user interface now that you are in, and consider creating your own named administrator account and disabling `admin`.

### Restoring existing data

A new instance initialises with a blank database. If you are migrating an existing DHIS2 into this deployment, restore your dump now, before letting users in — see [backup and restore](../reference/backup-restore.md). The dump carries its own users, so re-run `make start-instance` afterwards to re-apply the admin password from your env file.

## Step 5 — Put admin interfaces behind the VPN

Grafana and Glowroot are never published to the internet. They are served on `*.internal` hostnames that only resolve inside a WireGuard tunnel. Set that up now — until you do, you have no visibility into the instance you just started.

Edit `overlays/wireguard/.env` and set at least:

```dotenv
WIREGUARD_SERVER_URL=203.0.113.10     # public IP or FQDN that clients dial
WIREGUARD_PEERS=laptop,phone          # one config is generated per named peer
```

Start the VPN and export the certificate authority that clients must trust:

```shell
make start-vpn
make get-vpn-ca        # writes rootCA.pem to the current directory
```

**Verify:** the `wireguard` and `wireguard-proxy` containers are `Up`, `rootCA.pem` is written, and each peer's configuration and QR code exist under `overlays/wireguard/config/peer_<name>/`. Those files are root-owned; [VPN access](../reference/vpn.md) covers retrieving them.

On a client machine, import the peer configuration into a WireGuard client, install `rootCA.pem` into the operating system trust store, connect the tunnel, and open `https://grafana.internal`. Client setup differs by platform — macOS in particular needs an extra resolver file — so follow [VPN access](../reference/vpn.md) rather than improvising.

**Verify:**

- `https://grafana.internal` loads Grafana **only while the tunnel is up**, and is unreachable with it disconnected.
- You can log in as `admin` with `GRAFANA_ADMIN_PASSWORD` from `stacks/monitoring/.env`.
- The preloaded Traefik, PostgreSQL and host dashboards render with data.
- In Prometheus, the `prod` app and postgres targets are both **UP**.
- `https://prod.glowroot.internal` shows the Glowroot profiler for the instance. There is one route per instance, named `<instance>.glowroot.internal`.

Change the Grafana admin password after your first login.

## Step 6 — Set up and test backups

An untested backup is not a backup. Do this before the deployment carries anything you would miss.

```shell
PROJECT_NAME=prod make backup
```

**Verify:** two files appear under `backups/prod/` — a database dump and a file storage archive — both non-empty.

Then **test the restore path**, on a throwaway instance rather than your production one. Create a second instance, restore the dump into it, and confirm the data is there. [Backup and restore](../reference/backup-restore.md) has the commands; the [test environment guide](test-environment.md) covers standing up a disposable instance for exactly this.

Schedule `make backup` from cron or a systemd timer, and copy the resulting files **off the host**. Backups sitting on the same disk as the database do not protect you from losing that disk. Neither scheduling nor off-host copying is automated by this repository — you must set them up yourself.

## Running the deployment

### Adding more instances

Repeat steps 3 and 4 with a different name and hostname. The shared stacks need no changes.

```shell
APP_HOSTNAME=dev.example.com PROJECT_NAME=dev make create-instance
COMPOSE_OPTS=-d PROJECT_NAME=dev make start-instance
```

Each instance is fully isolated: its own database on its own network, its own credentials, its own configuration under `instances/<name>/`, its own Traefik route and Prometheus targets. Stopping one does not affect the others.

### Stopping and starting

```shell
PROJECT_NAME=prod make stop-instance    # containers down, routes and targets removed
PROJECT_NAME=prod make start-instance   # back up again
```

`stop-instance` keeps `instances/prod/.env` and all data volumes, so the instance can be restarted later. `delete-instance` is the destructive one: it removes the volumes and the instance directory, irreversibly. [Instance lifecycle](../reference/instance-lifecycle.md) lists precisely what each target changes.

### Tuning

The defaults are not tuned for your hardware or your data. This is one of the areas where the project is still immature, and it needs attention per deployment:

- **PostgreSQL** — memory, connections and logging, set per instance in `instances/<name>/postgresql/conf.d/`. See [PostgreSQL configuration](../reference/postgresql.md).
- **DHIS2** — `instances/<name>/dhis2/dhis.conf`, including connection pool sizing.
- **Container resources** — no CPU or memory limits are applied by default, so instances on a shared host can starve each other.

### Keeping an eye on it

Grafana's preloaded dashboards cover Traefik, PostgreSQL and the host. Logs from every container go to Loki, labelled by instance, so you can read them in Grafana instead of on the box. For request-level performance work, Glowroot and Tempo tracing are already running on each instance — see [profiling and APM](../reference/profiling.md).

## Tearing it all down

```shell
make stop-vpn
PROJECT_NAME=prod make stop-instance     # keeps instances/prod/.env and data
make clean-traefik
make clean-monitoring
```

To destroy an instance's data as well — irreversible:

```shell
PROJECT_NAME=prod make delete-instance
```

## What to read next

- [Instance lifecycle](../reference/instance-lifecycle.md) — the full `make` interface.
- [Backup and restore](../reference/backup-restore.md) — get this scheduled and tested.
- [Monitoring](../reference/monitoring.md) — retention settings and what is being collected.
- [Troubleshooting](../reference/troubleshooting.md) — when something does not come up.

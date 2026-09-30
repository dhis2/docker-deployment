# Troubleshooting

Symptoms, causes and fixes, grouped by what you were trying to do.

## First, look at the logs

Container names are Compose-generated, not the network aliases used elsewhere — the application container is `<name>-app-1`, not `<name>-app`, and Traefik is `traefik-traefik-1`. Addressing containers through Compose avoids having to know them:

```shell
# An instance's application
sudo docker compose --project-name <name> --env-file instances/<name>/.env logs app

# Follow it
sudo docker compose --project-name <name> --env-file instances/<name>/.env logs -f app

# An instance's database
sudo docker compose --project-name <name> --env-file instances/<name>/.env \
  -f stacks/postgres/docker-compose.yml logs database

# Traefik
sudo docker compose -f stacks/traefik/docker-compose.yml logs traefik
```

Add `SUDO=`-style direct invocation — drop `sudo` — on a laptop or dev container. With the monitoring stack running, the same logs are in Grafana, labelled by instance, which is usually easier to read.

Then check what is actually running:

```shell
make list-instances
sudo docker ps -a          # -a also shows containers that exited
```

## Starting an instance

### The instance never becomes healthy

Health checks are not enforced for the first 120 seconds, and a blank database takes a few minutes to initialise on top of that — DHIS2 is creating its schema. Watch the application log before concluding something is wrong.

If it is still not up after several minutes, look for:

- **Flyway migration errors** — usually a version mismatch. A database restored from a **newer** DHIS2 than `DHIS2_VERSION` cannot be migrated backwards. Align the versions.
- **Database connection failures** — `POSTGRES_DB_*` values in the instance env file not matching what the database was initialised with. This happens if the env file was edited or regenerated after the first start; the credentials are baked into the database volume at creation. Recreating the instance is the reliable fix.
- **Out of memory** — the JVM being killed. Give Docker more memory, or lower `shared_buffers` in the instance's PostgreSQL configuration.

### `create-instance` fails with "already exists"

`create-instance` refuses to overwrite an existing instance, deliberately, since regenerating the env file would produce new passwords that no longer match the existing database volume. To start over:

```shell
PROJECT_NAME=<name> make delete-instance   # destroys the data, irreversibly
```

### `generate-stack-envs` refuses to overwrite

Also deliberate. The three stack env files must stay consistent with every instance env file, because `create-instance` copies the monitoring credentials out of `stacks/monitoring/.env`. Either keep the existing files, or delete all three **together** and recreate your instances.

### Ports 80 or 443 already in use

Traefik cannot start. Something else — another Traefik, nginx, Apache, a local development server — holds the port:

```shell
sudo ss -tlnp '( sport = :80 or sport = :443 )'
```

Stop it, then `make start-traefik` again.

### `error while creating mount source` or a missing `instances/<name>/dhis2`

`start-instance` was run without `create-instance` having been run first, or with the wrong `PROJECT_NAME`. Since `PROJECT_NAME` defaults to the name of the current directory, a forgotten `PROJECT_NAME=` silently targets an instance named after your checkout. Check `make list-instances`.

## Certificates and reaching the site

### No trusted certificate is issued

Work through, in order:

1. **Does the hostname resolve publicly to this server?** `dig +short <hostname>` from somewhere other than the server. Let's Encrypt validates by connecting to that name; a DNS record that has not propagated is the most common cause.
2. **Is port 443 reachable from the internet?** Both the cloud provider's security group and the host firewall have to allow it.
3. **Is it a loopback nip.io name?** `*.127-0-0-1.nip.io` can never get a trusted certificate — Let's Encrypt cannot reach your laptop. Self-signed is the expected outcome there.
4. **Read Traefik's log** for ACME errors:

    ```shell
    sudo docker compose -f stacks/traefik/docker-compose.yml logs traefik | grep -i acme
    ```

### Rate-limited by Let's Encrypt

Production rate limits are strict and a few failed attempts can lock a hostname out for days. This is why the [production guide](../guides/production-deployment.md) starts on the staging CA. If you are already limited, switch to staging to keep working, and wait out the limit before switching back. See [TLS certificates](tls.md).

### The browser still shows the old certificate issuer after switching CA

Switching between staging and production leaves the old certificate in Traefik's `acme.json`. Stop Traefik, remove its `cert` volume, and start it again so it issues from scratch.

### Browser warns about the certificate on a local instance

Expected. Local hostnames get a self-signed certificate. Click through; use `curl -k`.

### `nip.io` will not resolve

Some networks and DNS resolvers block it. Add entries to `/etc/hosts` as a fallback:

```text
127.0.0.1 one.dhis2.127-0-0-1.nip.io two.dhis2.127-0-0-1.nip.io
```

### 404 from Traefik

The route file is missing or the hostname does not match. Check that `stacks/traefik/conf.d/<name>.yml` exists and that the `Host()` rule in it matches the name you are requesting exactly — `APP_HOSTNAME` is matched literally, with no wildcard behaviour.

## Logging in

### The admin password does not work

- **After restoring a dump:** the dump brought its own users, replacing yours. Run `PROJECT_NAME=<name> make start-instance` to re-apply `DHIS2_ADMIN_PASSWORD` from the env file, or log in with the dump's own credentials — `admin` / `district` for the DHIS2 demo databases.
- **After recreating an instance:** `create-instance` generated a **new** password. Read `instances/<name>/.env` again.
- **After changing it in the DHIS2 UI:** `update-admin-password` runs on every `start-instance` and resets `admin` to whatever the env file says. Update the env file too, or use a separate named account for yourself.

## Monitoring and the VPN

### Prometheus targets show DOWN

- **DHIS2 targets:** the `DHIS2_MONITOR_*` values in the instance env file must match `stacks/monitoring/.env`. They drift apart if the monitoring env was regenerated after the instance was created. The `create-monitoring-user` job also has to have completed successfully — check its log.
- **Postgres targets:** check the `postgres-exporter` container is running and that `POSTGRES_METRICS_*` in the instance env file are intact.
- **Either:** confirm the instance's target file exists under `stacks/monitoring/targets/`.

### `grafana.internal` is unreachable

Both things are required: the tunnel must be **up**, and `rootCA.pem` must be installed in the client's trust store.

- On the VPN's first start, Traefik may have loaded before the certificates existed. `make start-vpn` touches `conf.d/internal.yml` to force a reload; if you see certificate errors, run it again.
- Use `https://`. Only port 443 is forwarded through the tunnel, so an `http://` URL fails with a connection refused.
- On macOS, `.internal` names need an explicit resolver file. On Linux with NetworkManager, they need the `~internal` search domain. Both are covered in [VPN access](vpn.md).
- Firefox has its own trust store and needs the CA imported separately.

### WireGuard handshake fails on a macOS host

In Docker Desktop, disable *Settings → Resources → Network → "Use kernel networking for UDP"*. With it enabled, inbound UDP has its source address rewritten before delivery, which breaks the handshake.

## Backup and restore

### `Restore file /backups/... not found`

`DB_RESTORE_FILE` is relative to `backups/<PROJECT_NAME>/`, not to the repository. Pass the bare filename, and confirm the file is in that instance's directory — not another instance's.

### `Unsupported file format`

Restore accepts `.sql.gz` (plain) and `.pgc` (custom), chosen by extension. Renaming a file does not convert it.

### Restore succeeds but dashboards are empty

Analytics tables are excluded from backups by design, since DHIS2 regenerates them. Run analytics generation after restoring — *Data Administration → Analytics Tables*, or `POST /api/resourceTables/analytics`. See [backup and restore](backup-restore.md).

## Still stuck

Ask in the DHIS2 Community of Practice, in [DHIS2 on Docker](https://community.dhis2.org/c/server-administration/docker/95). Include your DHIS2 version, whether you are on a server or a laptop, the `make` command you ran, and the relevant container log — with credentials removed.

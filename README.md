# Docker Deployment

Docker production deployment of the DHIS2 application

## Quick Start

### Configure Environment

The following environment variables are required for setting up the environment

```shell
export GEN_APP_HOSTNAME=<the hostname of the application>
export GEN_LETSENCRYPT_ACME_EMAIL=<your email address>
```

Generate a new `.env` file by executing the following command

```shell
./scripts/generate-env.sh
```

Potentially adjust the generated `.env` file to your needs. However, it's highly recommended not to change the generated
values of the password variables.

Documentation for the environment variables can be found [here](docs/environment-variables.md).

### Launch the application

```shell
docker compose up
```

Open http://dhis2-127-0-0-1.nip.io in your favourite browser.

## Postgresql configuration

Custom configuration for Postgresql can be done by adding to the files in the `./config/postgresql/conf.d/` directory. If your configuration doesn't belong in either of the existing files, you can create a new file. However, it's advised not to make changes to the [postgresql.conf](config/postgresql/postgresql.conf) file.

Any changes to these files won't take effect until the container is restarted or the below command is executed:

```sql
SELECT pg_reload_conf();
```

## Overlays

### Traefik Dashboard

The Traefik dashboard can be enabled by launching the application with the following command

```shell
docker compose -f docker-compose.yml -f overlays/traefik-dashboard/docker-compose.yml up
```

### Monitoring

The monitoring stack includes Grafana, Loki, and Prometheus for logs and metrics collection. It can be enabled by
applying the monitoring overlay:

```shell
docker compose -f docker-compose.yml -f overlays/monitoring/docker-compose.yml up
```

More details in the [Monitoring section](#monitoring-1)

### Glowroot

Glowroot can be enabled by launching the application with the following command

```shell
docker compose -f docker-compose.yml -f overlays/glowroot/docker-compose.yml up
```

## Backup and Restore

Backups are stored in the `./backups` directory.

We support backup of both the database and the file storage.

### Backup

A complete backup of both database and file storage can be created by executing the following command

```shell
make backup
```

Execute the above command should create two files in the `./backups` directory. One for the database and one for the
file storage. Please see the [Backup Database](#backup-database) and [Backup File Storage](#backup-file-storage)
sections for more details.

#### Backup Database

The database can be backed up in two different formats: `custom` and `plain`. The default format is `custom` but it can
be changed by setting the `POSTGRES_BACKUP_FORMAT` environment variable to either value.

A backup of the database can be created by executing the following command

```shell
make backup-database
```

Execute the above command should create a file in the `./backups` directory. The file name will be `$TIMESTAM.pgc` if
the `POSTGRES_BACKUP_FORMAT` environment variable is set to `custom` or `$TIMESTAMP.sql.gz` if the
`POSTGRES_BACKUP_FORMAT` environment variable is set to `plain`. Please consult
the [PostgreSQL documentation](https://www.postgresql.org/docs/current/app-pgdump.html) for more details.

#### Backup File Storage

A backup of the file storage can be created by executing the following command

```shell
make backup-file-storage
```

### Restore

The restore process relies on the `DB_RESTORE_FILE` and `FILE_STORAGE_RESTORE_SOURCE_DIR` environment variables to be
set to the path of the backup file to restore. Note that both variable values must be set without the folder prefix and
the files must be in the `./backups` directory.

A complete restore of both database and file storage can be done by executing the following command

```shell
make restore
```

#### Restore Database

The database to restore can be set by setting the `DB_RESTORE_FILE` environment variable.

Restoring just the database can be done by executing the following command

```shell
make restore-database
```

#### Restore File Storage

The file storage to restore can be set by setting the `FILE_STORAGE_RESTORE_SOURCE_DIR` environment variable.

Restoring just the file storage can be done by executing the following command

```shell
make restore-file-storage
```

## Monitoring

The monitoring stack includes Grafana, Loki, and Prometheus for logs and metrics collection.

### Prerequisites

The Docker Loki Driver plugin is required

```shell
./scripts/install-loki-driver.sh
```

### Monitoring

The monitoring stack can be deployed using the following command:

```shell
docker compose -f docker-compose.yml -f overlays/monitoring/docker-compose.yml up
```

This will deploy the following components:

#### Grafana

A web-based monitoring and visualization platform which will serve as your main entry point for everything monitoring
related.

Grafana comes preloaded with a set of dashboards covering

- **Traefik** – reverse proxy request and performance metrics
- **PostgreSQL** – database health and performance metrics
- **Server/Host data** – CPU, memory, disk, and network usage (via Node Exporter and cAdvisor)

These dashboards are automatically provisioned and ready to use.

#### Prometheus

Prometheus is responsible for collecting and storing metrics across the stack.
It runs on a *pull model*: Prometheus regularly scrapes metrics endpoints exposed by other services and stores the
results in its own time-series database.

In this setup, Prometheus collects metrics from

- **DHIS2 application** – via the `/api/metrics` endpoint (application health, JVM, database pool, etc.)
- **Postgres Exporter** – PostgreSQL database metrics (queries, cache hits, connections)
- **Traefik** – reverse proxy metrics (requests, response codes, latency)
- **Node Exporter** – host system metrics (CPU, memory, disk, network)
- **cAdvisor** – container-level metrics (CPU, memory, filesystem, network usage)
- **Prometheus itself** – self-monitoring metrics

Data is stored locally in Prometheus with a retention period of 15 days (by default), and Grafana is preconfigured to
use Prometheus as a data source for dashboards.

#### Loki

Loki is responsible for log aggregation. All container logs are automatically forwarded to Loki using the Docker Loki
Driver plugin.

Logs collected include

- **DHIS2** – application logs
- **PostgreSQL** – database logs
- **Traefik** – reverse proxy logs

These logs are indexed by labels (not full-text), making Loki lightweight and efficient. Grafana connects to Loki to
provide a searchable log interface alongside your metrics dashboards.

#### DHIS2 Monitoring

DHIS2's built-in monitoring API is enabled, exposing health and performance metrics to Prometheus for collection.

### Accessing Monitoring Services

1. Start the services with monitoring overlay
2. Open https://grafana.{APP_HOSTNAME} in your browser (where `{APP_HOSTNAME}` is defined in your `.env` file)
3. Login with:
    - Username: `admin`
    - Password: check your `.env` file for `GRAFANA_ADMIN_PASSWORD`

### Configuration

Monitoring settings can be configured via environment variables in your `.env` file:

- `GRAFANA_ADMIN_PASSWORD`: Grafana admin password (auto-generated)
- `PROMETHEUS_RETENTION_TIME`: Prometheus data retention (default: 15d)
- `LOKI_RETENTION_PERIOD`: Loki log retention (default: 744h = 31 days)

## Set up development environment

### Prerequisites

- Python 3.11+
- Make

```shell
make init
```

### Start all services

```shell
make launch
```

### Clean all services

```shell
make clean
```

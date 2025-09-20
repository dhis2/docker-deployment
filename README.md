# Docker Deployment

Docker production deployment of the DHIS2 application

## Quick Start

### Configure Environment

Generate a new `.env` file by executing the following command

```shell
./scripts/generate_env.sh
```

Potentially adjust the generated `.env` file to your needs. However, it's highly recommended not to change the generated values of the password variables.

Documentation for the environment variables can be found [here](docs/environment-variables.md).

### Automatic Certificate Management Environment

The acme file needs to be owned, only writable, by the same user running Traefik

```shell
touch ./traefik/acme.json
sudo chown 65534:65534 ./traefik/acme.json
sudo chmod 600 ./traefik/acme.json
```

### Launch the application

```shell
docker compose up
```

Open http://dhis2-127-0-0-1.nip.io in your favourite browser.

## Overlays

### Traefik Dashboard

The Traefik dashboard can be enabled by launching the application with the following command

```shell
docker compose -f docker-compose.yml -f overlays/docker-compose.traefik-dashboard.yml up
```

### Monitoring

For comprehensive monitoring including Grafana, Loki, and Prometheus, use the monitoring overlay:

```shell
docker compose -f docker-compose.yml -f overlays/docker-compose.monitoring.yml up
```

More details in the [Monitoring section](#monitoring-1)

## Backup and Restore

Backups are stored in the `./backups` directory.

We support backup of both the database and the file storage.

### Backup

A complete backup of both database and file storage can be created by executing the following command

```shell
make backup
```

Execute the above command should create two files in the `./backups` directory. One for the database and one for the file storage. Please see the [Backup Database](#backup-database) and [Backup File Storage](#backup-file-storage) sections for more details.

#### Backup Database

The database can be backed up in two different formats: `custom` and `plain`. The default format is `custom` but it can be changed by setting the `POSTGRES_BACKUP_FORMAT` environment variable to either value.

A backup of the database can be created by executing the following command

```shell
make backup-database
```

Execute the above command should create a file in the `./backups` directory. The file name will be `$TIMESTAM.pgc` if the `POSTGRES_BACKUP_FORMAT` environment variable is set to `custom` or `$TIMESTAMP.sql.gz` if the `POSTGRES_BACKUP_FORMAT` environment variable is set to `plain`. Please consult the [PostgreSQL documentation](https://www.postgresql.org/docs/current/app-pgdump.html) for more details.

#### Backup File Storage

A backup of the file storage can be created by executing the following command

```shell
make backup-file-storage
```

### Restore

The restore process relies on the `DB_RESTORE_FILE` and `FILE_STORAGE_RESTORE_SOURCE_DIR` environment variables to be set to the path of the backup file to restore. Note that both variable values must be set without the folder prefix and the files must be in the `./backups` directory.

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

This deployment supports optional monitoring through Docker Compose overlays. The monitoring stack includes Grafana, Loki, and Prometheus for logs and metrics collection.

### Prerequisites

Before starting the monitoring services, you need to install the Docker Loki Driver plugin:

```shell
./scripts/install-loki-driver.sh
```

**Note**: The plugin is only required when using the monitoring overlay.

### Basic Monitoring

Start the core application with monitoring:

```shell
docker compose -f docker-compose.yml -f overlays/docker-compose.monitoring.yml up
```

This enables:

- **Grafana** (https://grafana.{HOSTNAME}): Web-based monitoring and visualization platform
- **Prometheus** (https://prometheus.{HOSTNAME}): Metrics collection and storage
- **Loki** (https://loki.{HOSTNAME}): Log aggregation system
- **DHIS2 Monitoring**: Enables DHIS2's built-in monitoring APIs

### Accessing Monitoring Services

1. Start the services with monitoring overlay
2. Open https://grafana.{HOSTNAME} in your browser
3. Login with:
   - Username: `admin`
   - Password: Check your `.env` file for `GRAFANA_ADMIN_PASSWORD`

### Log Aggregation

All container logs are automatically sent to Loki using the Docker Loki Driver plugin:

- **DHIS2**: Application logs
- **PostgreSQL**: Database logs
- **Traefik**: Reverse proxy logs

### Metrics Collection

Prometheus automatically collects metrics from:

- DHIS2 application (via the `/api/metrics` endpoint)
- Prometheus itself

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

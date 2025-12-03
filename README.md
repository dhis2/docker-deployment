# Docker Deployment

This repository provides a Docker-based deployment for the DHIS2 application, designed for both local development/testing and secure production implementations. It leverages Docker Compose to orchestrate DHIS2, PostgreSQL, Traefik (as a reverse proxy), and an optional monitoring stack. Facilities are also provided for backup and restore of the database and file storage.

## Table of contents

- [Deployment For Local Development and Testing](#deployment-for-local-development-and-testing)
- [Deployment For Production Implementations](#deployment-for-production-implementations)
- [Advanced Usage](#advanced-usage)
  - [PostgreSQL Configuration](#postgresql-configuration)
  - [Additional Services (Overlays)](#additional-services-overlays)
    - [Traefik Dashboard](#traefik-dashboard)
    - [Glowroot](#glowroot)
  - [Backup and Restore](#backup-and-restore)
    - [Backup](#backup)
    - [Restore](#restore)
  - [Monitoring](#monitoring)
    - [Prerequisites](#prerequisites)
    - [Monitoring Deployment](#monitoring-deployment)
    - [DHIS2 Monitoring](#dhis2-monitoring)
    - [Accessing Monitoring Services](#accessing-monitoring-services)
    - [Configuration](#configuration)
- [Contributing to this project](#contributing-to-this-project)
- [Further Documentation](#further-documentation)

## Deployment For Local Development and Testing

This section is for users who want to quickly set up and test the DHIS2 application on their local machine.

### Configure Environment

The following environment variables are required to configure the application.

```shell
# The following hostname is a convenient representation of the local machine's IP address.
export GEN_APP_HOSTNAME=dhis2-127-0-0-1.nip.io
# A valid email address is required for Let's Encrypt certificate management.
export GEN_LETSENCRYPT_ACME_EMAIL=your@email.com
```

Generate a new `.env` file by executing the following command:

```shell
./scripts/generate-env.sh
```

You can adjust the generated `.env` file to your specific needs. However, it is recommended not to change the generated values of the password variables for consistency.

Detailed documentation for all environment variables can be found [here](docs/environment-variables.md).

### Launch the application

Once the environment is configured, launch the application using Docker Compose:

```shell
docker compose up
```

Open `http://dhis2-127-0-0-1.nip.io` in your favorite browser.

> **Note**
> The first time you launch the application, it will initialise with a blank database. *The default admin credentials are available in the `.env` file.* If you have an existing database, you can restore it following the [Backup and Restore](#backup-and-restore) section, under Advanced Usage, below.

## Deployment For Production Implementations

This section is for users planning to deploy DHIS2 in a production environment.

### Deployment Prerequisites

Before deploying to production, ensure you have:

- A dedicated host or virtual machine with Docker and Docker Compose installed.
- A fully qualified domain name (FQDN) for your DHIS2 instance.
- A valid email address for Let's Encrypt certificate management.
- Appropriate firewall rules configured for ports 80 and 443.

### Configure Environment

The following environment variables are required to configure the application.

```shell
# Provide the FQDN for your DHIS2 instance.
export GEN_APP_HOSTNAME=<your-domain.com>
# A valid email address is required for Let's Encrypt certificate management.
export GEN_LETSENCRYPT_ACME_EMAIL=your@email.com
```

Generate a new `.env` file by executing the following command:

```shell
./scripts/generate-env.sh
```

For production, carefully review and configure all environment variables in your `.env` file. Refer to the comprehensive [environment variables documentation](docs/environment-variables.md) for details on each variable. It is recommended not to change the generated values of the password variables unless you need to do so to align with your organization's security policies, or existing components.

### Launch the application

Once the environment is configured, launch the application using Docker Compose:

```shell
docker compose up
```

Open `https://<your-domain.com>` in your favorite browser.

> **Note**
> The first time you launch the application, it will initialise with a blank database. *The default admin credentials are available in the `.env` file.* If you have an existing database, you can restore it following the [Backup and Restore](#backup-and-restore) section, under Advanced Usage, below.

## Advanced Usage

### PostgreSQL Configuration

For production environments, careful configuration of PostgreSQL is critical for performance and stability.

Custom configuration for PostgreSQL should be done by adding `.conf` files to the `./config/postgresql/conf.d/` directory. Create new files for specific settings rather than modifying existing ones or `config/postgresql/postgresql.conf`.

Any changes to these files will require a restart of the PostgreSQL container to take effect. For changes to take effect without restarting the container, you can execute (inside the PostgreSQL container):

```sql
SELECT pg_reload_conf();
```

### Additional Services (Overlays)

Deployments can benefit from additional services provided by compose overlays.

#### Traefik Dashboard

To enable the Traefik dashboard for local monitoring of your reverse proxy, launch the application with the following command:

```shell
docker compose -f docker-compose.yml -f overlays/traefik-dashboard/docker-compose.yml up
```

#### Glowroot

Glowroot is an APM (Application Performance Monitoring) tool that can be enabled to monitor the DHIS2 application's performance in production.

```shell
docker compose -f docker-compose.yml -f overlays/glowroot/docker-compose.yml up
```

### Backup and Restore

Robust backup and restore procedures are essential for production. Backups are stored in the `./backups` directory. We support backup and restore of both the database and the file storage.

#### Backup

A complete backup of both the database and file storage can be created by executing:

```shell
make backup
```

This command will create two files in the `./backups` directory: one for the database and one for the file storage.

- **Backup Database**: The database can be backed up in `custom` (default) or `plain` format, controlled by the `POSTGRES_BACKUP_FORMAT` environment variable.

    ```shell
    make backup-database
    ```

    This creates a file in `./backups` named `$TIMESTAMP.pgc` (custom) or `$TIMESTAMP.sql.gz` (plain). Consult the [PostgreSQL documentation](https://www.postgresql.org/docs/current/app-pgdump.html) for more details.

- **Backup File Storage**:

    ```shell
    make backup-file-storage
    ```

#### Restore

The restore process relies on the `DB_RESTORE_FILE` and `FILE_STORAGE_RESTORE_SOURCE_DIR` environment variables, which must be set to the path of the backup file/directory to restore (without the `./backups` prefix).

A complete restore of both database and file storage can be done by executing:

```shell
make restore
```

- **Restore Database**: Set the `DB_RESTORE_FILE` environment variable to the backup file name.

    ```shell
    make restore-database
    ```

- **Restore File Storage**: Set the `FILE_STORAGE_RESTORE_SOURCE_DIR` environment variable to the backup directory name.

    ```shell
    make restore-file-storage
    ```

### Monitoring

The monitoring stack is crucial for understanding the health and performance of your production DHIS2 deployment. It includes Grafana, Loki, and Prometheus for logs and metrics collection.

#### Prerequisites

The Docker Loki Driver plugin is required to forward container logs to Loki. Install it using:

```shell
./scripts/install-loki-driver.sh
```

#### Monitoring Deployment

Deploy the monitoring stack using:

```shell
docker compose -f docker-compose.yml -f overlays/monitoring/docker-compose.yml up
```

This deploys:

- **Grafana**: A web-based monitoring and visualization platform with preloaded dashboards for Traefik, PostgreSQL, and server/host data.
- **Prometheus**: Collects metrics from the DHIS2 application (`/api/metrics`), Postgres Exporter, Traefik, Node Exporter, cAdvisor, and Prometheus itself. Data is stored locally for 15 days (default).
- **Loki**: Aggregates all container logs (DHIS2, PostgreSQL, Traefik) via the Docker Loki Driver plugin. Logs are indexed by labels for efficiency.

#### DHIS2 Monitoring

DHIS2's built-in monitoring API is enabled, exposing health and performance metrics to Prometheus.

#### Accessing Monitoring Services

1. Start services with the monitoring overlay (as shown above).
2. Open `https://grafana.{APP_HOSTNAME}` in your browser (where `{APP_HOSTNAME}` is from your `.env` file).
3. Login with:
    - Username: `admin`
    - Password: Check your `.env` file for `GRAFANA_ADMIN_PASSWORD`.

#### Configuration

Monitoring settings can be configured via environment variables in your `.env` file:

- `GRAFANA_ADMIN_PASSWORD`: Grafana admin password (auto-generated).
- `PROMETHEUS_RETENTION_TIME`: Prometheus data retention (default: `15d`).
- `LOKI_RETENTION_PERIOD`: Loki log retention (default: `744h` = 31 days).

## Contributing to this project

This section is for developers who want to contribute to this project.

### Prerequisites

- Python 3.11+
- Pip
- Make

To initialize the development environment:

```shell
make init
```

### Start all services

To start all services for development:

```shell
make launch
```

### Clean all services

To stop and remove all services and their associated data:

```shell
make clean
```

## Further Documentation

For more in-depth information, please refer to the following:

- [Environment Variables](docs/environment-variables.md)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/app-pgdump.html)

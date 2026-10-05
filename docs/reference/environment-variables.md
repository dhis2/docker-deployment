# Environment Variables Documentation

## File: `./docker-compose.yml`

### Service: app

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `DHIS2_IMAGE_REPOSITORY` |  | `dhis2/core` |
| `DHIS2_VERSION` |  | `43` |

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `COMPOSE_PROJECT_NAME` |  | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `SYSTEM_AUDIT_ENABLED` | Enable system audit logging | `off` |

### Service: update-admin-password

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `DHIS2_ADMIN_USERNAME` | DHIS2 admin username | `-` |
| `DHIS2_ADMIN_PASSWORD` | DHIS2 admin password | `-` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: create-monitoring-user

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `DHIS2_HOSTNAME` | Base URL the monitoring user is created against | `http://app:8080` |
| `DHIS2_ADMIN_USERNAME` | DHIS2 admin username | `-` |
| `DHIS2_ADMIN_PASSWORD` | DHIS2 admin password | `-` |
| `DHIS2_MONITOR_USERNAME` | DHIS2 user Prometheus scrapes as; must match stacks/monitoring/.env | `-` |
| `DHIS2_MONITOR_PASSWORD` | Password for the monitoring user; must match stacks/monitoring/.env | `-` |

### Service: postgres-exporter

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_EXPORTER_VERSION` |  | `v0.17.1` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_METRICS_USERNAME` | Metrics user credentials used to scrape PostgreSQL | `-` |
| `POSTGRES_METRICS_PASSWORD` | Metrics user credentials used to scrape PostgreSQL | `-` |
| `POSTGRES_DB` | Name of the database to use | `-` |

## File: `overlays/glowroot/docker-compose.yml`

### Service: app

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `JDK_JAVA_OPTIONS` | Extra JVM options; the Glowroot agent is appended to whatever is set | `-` |

### Service: glowroot-init

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `CURL_VERSION` |  | `8.10.1` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GLOWROOT_VERSION` | Glowroot agent version to download | `0.14.4` |
| `EXPECTED_SHA` | SHA256 the downloaded Glowroot agent must match | `3b9db6b0fc0903233c5e17b6cfa7b022ef8ba6d71ae7d39a9fff6f637608f20c` |
| `APP_UID` | User ID owning the agent files; match the app container's user | `65534` |
| `APP_GID` | Group ID owning the agent files; match the app container's group | `65534` |

## File: `overlays/profiling/docker-compose.yml`

### Service: app

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `COMPOSE_PROJECT_NAME` | Instance name; set by make from PROJECT_NAME | `-` |

### Service: tempo

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `TEMPO_VERSION` |  | `2.3.1` |

### Service: otel-init

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `CURL_VERSION` |  | `8.10.1` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `OTEL_VERSION` | OpenTelemetry Java agent version to download | `2.11.0` |
| `OTEL_JAR_SHA256` | SHA256 the downloaded agent JAR must match | `4cff4ab46179260a61fc0d884f3f170cfbd9d2962dd260be2cff31262d0c7618` |

#### Command

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `OTEL_VERSION` | OpenTelemetry Java agent version to download | `-` |
| `OTEL_JAR_SHA256` | SHA256 the downloaded agent JAR must match | `-` |

## File: `overlays/wireguard/docker-compose.yml`

### Service: wireguard

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_VERSION` |  | `latest` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_SERVER_URL` | Public endpoint clients connect to; 'auto' detects it | `auto` |
| `WIREGUARD_SERVER_PORT` | UDP port WireGuard listens on | `51820` |
| `WIREGUARD_PEERS` | Comma-separated peer names to generate client configs for | `laptop` |
| `WIREGUARD_INTERNAL_SUBNET` | Tunnel subnet; must not overlap the client's local networks | `10.8.0.0` |
| `WIREGUARD_ALLOWED_IPS` | CIDRs the client routes through the tunnel; the generated .env sets a split tunnel | `0.0.0.0/0` |

#### Ports

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_SERVER_PORT` | UDP port WireGuard listens on | `51820` |

## File: `stacks/backup/docker-compose.yml`

### Service: backup-database

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_DIR` | Host directory for this instance's backups (./backups/<PROJECT_NAME>) | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Database username | `dhis` |
| `POSTGRES_BACKUP_FORMAT` | Database backup format | `custom` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: backup-file-storage

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_DIR` | Host directory for this instance's backups (./backups/<PROJECT_NAME>) | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_TIMESTAMP` | Backup timestamp. Used to name the backup directory and the backup file. Since those are created by different containers, we need to ensure the backup timestamp is the same for both containers. | `-` |
| `BACKUP_SOURCE_PATH` | Directory to back up | `/opt/dhis2/files` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `RCLONE_VERSION` |  | `1.68` |

### Service: restore-database

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_DIR` | Host directory for this instance's backups (./backups/<PROJECT_NAME>) | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Database username | `dhis` |
| `POSTGRES_PASSWORD` | The `PGPASSWORD` environment variable is used by the `pg_dump` command` | `-` |
| `DB_RESTORE_FILE` | Database restore file | `-` |
| `DB_RESTORE_NUMBER_OF_JOBS` | Number of parallel jobs for pg_restore | `4` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: restore-file-storage

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_DIR` | Host directory for this instance's backups (./backups/<PROJECT_NAME>) | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `FILE_STORAGE_RESTORE_SOURCE_DIR` | Directory to restore from | `-` |
| `RESTORE_DESTINATION_PATH` | Directory to restore to | `/opt/dhis2/files` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `RCLONE_VERSION` |  | `1.68` |

## File: `stacks/monitoring/docker-compose.yml`

### Service: grafana

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GRAFANA_VERSION` |  | `10.0.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password, generated into stacks/monitoring/.env | `-` |

### Service: loki

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOKI_VERSION` |  | `2.9.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOKI_RETENTION_PERIOD` | How long container logs are kept (744h = 31 days) | `744h` |

### Service: prometheus

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `PROMETHEUS_VERSION` |  | `v2.45.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `PROMETHEUS_RETENTION_TIME` | How long metrics are kept | `15d` |

#### Command

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `PROMETHEUS_RETENTION_TIME` | How long metrics are kept | `15d` |

### Service: node-exporter

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `NODE_EXPORTER_VERSION` |  | `v1.6.1` |

### Service: cadvisor

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `CADVISOR_VERSION` |  | `v0.47.0` |

## File: `stacks/postgres/docker-compose.yml`

### Service: database

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `COMPOSE_PROJECT_NAME` | Instance name; set by make from PROJECT_NAME | `-` |
| `COMPOSE_PROJECT_NAME` | Instance name; set by make from PROJECT_NAME | `-` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `POSTGRES_DB` | Name of the database | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_METRICS_USERNAME` | Metrics username | `-` |
| `POSTGRES_METRICS_PASSWORD` | Metrics user password | `-` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

## File: `stacks/traefik/docker-compose.yml`

### Service: traefik

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOG_LEVEL` | Log level | `INFO` |
| `LOG_ACCESS` | Enable access logs | `true` |
| `LOG_FORMAT` | Access log format | `json` |
| `LETSENCRYPT_ACME_EMAIL` | Email address Let's Encrypt registers certificates and expiry notices to | `-` |
| `LETSENCRYPT_ACME_CASERVER` | ACME directory URL; point at the staging CA while testing to avoid rate limits | `https://acme-v02.api.letsencrypt.org/directory` |

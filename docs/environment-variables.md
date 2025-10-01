# Environment Variables Documentation

## File: `../src/docker-compose.yml`

### Service: app

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `DHIS2_VERSION` |  | `42` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |

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

### Service: database

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_METRICS_USERNAME` | Metrics username | `-` |
| `POSTGRES_METRICS_PASSWORD` | Metrics user password | `-` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: traefik

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOG_LEVEL` | Log level | `INFO` |
| `LOG_ACCESS` | Enable access logs | `true` |
| `LOG_FORMAT` | Access log format | `json` |
| `LETSENCRYPT_ACME_EMAIL` | ACME email | `-` |
| `APP_HOSTNAME` | Hostname | `-` |

### Service: backup-database

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_BACKUP_FORMAT` | Database backup format | `custom` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: backup-file-storage

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

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `DB_RESTORE_FILE` | Database restore file | `-` |
| `DB_RESTORE_NUMBER_OF_JOBS` | Number of parallel jobs for pg_restore | `4` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_VERSION` |  | `16-master` |

### Service: restore-file-storage

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `FILE_STORAGE_RESTORE_SOURCE_DIR` | Directory to restore from | `-` |
| `RESTORE_DESTINATION_PATH` | Directory to restore to | `/opt/dhis2/files` |

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `RCLONE_VERSION` |  | `1.68` |

## File: `../src/overlays/glowroot/docker-compose.yml`

### Service: app

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `JDK_JAVA_OPTIONS` |  | `-` |

### Service: glowroot-init

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `CURL_VERSION` |  | `8.10.1` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GLOWROOT_VERSION` |  | `0.14.0` |
| `APP_UID` |  | `65534` |
| `APP_GID` |  | `65534` |

## File: `../src/overlays/monitoring/docker-compose.yml`

### Service: create-monitoring-user

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `DHIS2_HOSTNAME` |  | `http://app:8080` |
| `DHIS2_ADMIN_USERNAME` |  | `-` |
| `DHIS2_ADMIN_PASSWORD` |  | `-` |
| `DHIS2_MONITOR_USERNAME` |  | `-` |
| `DHIS2_MONITOR_PASSWORD` |  | `-` |

### Service: grafana

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GRAFANA_VERSION` |  | `10.0.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `GRAFANA_ADMIN_PASSWORD` |  | `-` |
| `APP_HOSTNAME` |  | `-` |

### Service: loki

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOKI_VERSION` |  | `2.9.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOKI_RETENTION_PERIOD` |  | `744h` |

### Service: prometheus

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `PROMETHEUS_VERSION` |  | `v2.45.0` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `PROMETHEUS_RETENTION_TIME` |  | `15d` |

### Service: postgres-exporter

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_EXPORTER_VERSION` |  | `v0.17.1` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_METRICS_USERNAME` |  | `-` |
| `POSTGRES_METRICS_PASSWORD` |  | `-` |
| `POSTGRES_DB` |  | `-` |

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

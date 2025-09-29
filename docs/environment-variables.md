# Environment Variables Documentation

## File: `../src/docker-compose.yml`

### Service: app

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_DB` | Name of the database to use | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |

### Service: update-admin-password

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_HOST` | Database hostname | `database` |
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `POSTGRES_DB` | Name of the database | `dhis` |
| `DHIS2_ADMIN_USERNAME` | DHIS2 admin username | `-` |
| `DHIS2_ADMIN_PASSWORD` | DHIS2 admin password | `-` |

### Service: database

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_PASSWORD` | Postgres user password | `-` |
| `POSTGRES_DB` | Name of the database | `dhis` |
| `POSTGRES_DB_USERNAME` | Database username | `-` |
| `POSTGRES_DB_PASSWORD` | Database password | `-` |
| `POSTGRES_INITDB_ARGS` | Initdb arguments | `--auth-host=scram-sha-256 --auth-local=scram-sha-256` |
| `POSTGRES_METRICS_USERNAME` | Metrics username | `-` |
| `POSTGRES_METRICS_PASSWORD` | Metrics user password | `-` |

### Service: traefik

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `TRAEFIK_LOG_LEVEL` | Log level | `INFO` |
| `TRAEFIK_ACCESSLOG` | Enable access logs | `true` |
| `TRAEFIK_ACCESSLOG_FORMAT` | Access log format | `json` |
| `TRAEFIK_PING` | Allow ping | `True` |
| `TRAEFIK_ENTRYPOINTS_WEB_ADDRESS` | Default entrypoint port | `:80` |
| `TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_TO` | Redirect to https | `websecure` |
| `TRAEFIK_ENTRYPOINTS_WEB_HTTP_REDIRECTIONS_ENTRYPOINT_SCHEME` | Redirect scheme | `https` |
| `TRAEFIK_ENTRYPOINTS_WEBSECURE_ADDRESS` | Default secure entrypoint port | `:443` |
| `TRAEFIK_PROVIDERS_FILE_FILENAME` | Provider file | `/etc/traefik/dynamic.yml` |
| `TRAEFIK_PROVIDERS_FILE_WATCH` | Watch the provider file for changes | `False` |
| `TRAEFIK_API` | Enable API | `True` |
| `TRAEFIK_API_INSECURE` | Allow insecure API access | `True` |
| `TRAEFIK_METRICS_PROMETHEUS` | Enable Prometheus metrics | `True` |
| `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL` | ACME email | `-` |
| `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_STORAGE` | ACME storage file | `/cert/acme.json` |
| `TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_TLSCHALLENGE` | ACME DNS challenge | `True` |
| `APP_HOSTNAME` | Hostname | `-` |

### Service: backup-database

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_HOST` | Database hostname | `database` |
| `POSTGRES_USER` | Database username | `-` |
| `POSTGRES_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Database name | `dhis` |
| `POSTGRES_BACKUP_FORMAT` | Database backup format | `custom` |
| `PGPASSWORD` | The `PGPASSWORD` environment variable is used by the `pg_dump` command` | `-` |

### Service: backup-file-storage

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `BACKUP_TIMESTAMP` | Backup timestamp. Used to name the backup directory and the backup file. Since those are created by different containers, we need to ensure the backup timestamp is the same for both containers. | `-` |
| `BACKUP_SOURCE_PATH` | Directory to back up | `/opt/dhis2/files` |

### Service: restore-database

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `POSTGRES_HOST` | Database hostname | `database` |
| `POSTGRES_USER` | Database username | `-` |
| `POSTGRES_PASSWORD` | Database password | `-` |
| `POSTGRES_DB` | Database name | `dhis` |
| `PGPASSWORD` | The `PGPASSWORD` environment variable is used by the `pg_dump` command` | `-` |
| `DB_RESTORE_FILE` | Database restore file | `-` |
| `DB_RESTORE_NUMBER_OF_JOBS` | Number of parallel jobs for pg_restore | `4` |

### Service: restore-file-storage

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `FILE_STORAGE_RESTORE_SOURCE_DIR` | Directory to restore from | `-` |
| `RESTORE_DESTINATION_PATH` | Directory to restore to | `/opt/dhis2/files` |

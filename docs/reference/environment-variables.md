# Environment Variables Documentation

## File: `../src/docker-compose.yml`

### Service: app

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
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
| `DHIS2_HOSTNAME` |  | `http://app:8080` |
| `DHIS2_ADMIN_USERNAME` | DHIS2 admin username | `-` |
| `DHIS2_ADMIN_PASSWORD` | DHIS2 admin password | `-` |
| `DHIS2_MONITOR_USERNAME` |  | `-` |
| `DHIS2_MONITOR_PASSWORD` |  | `-` |

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
| `POSTGRES_DB` | Name of the database to use | `-` |

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
| `GLOWROOT_VERSION` |  | `0.14.4` |
| `EXPECTED_SHA` |  | `3b9db6b0fc0903233c5e17b6cfa7b022ef8ba6d71ae7d39a9fff6f637608f20c` |
| `APP_UID` |  | `65534` |
| `APP_GID` |  | `65534` |

## File: `../src/overlays/profiling/docker-compose.yml`

### Service: app

#### Volumes

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `COMPOSE_PROJECT_NAME` |  | `-` |

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
| `OTEL_VERSION` |  | `2.11.0` |
| `OTEL_JAR_SHA256` |  | `4cff4ab46179260a61fc0d884f3f170cfbd9d2962dd260be2cff31262d0c7618` |

#### Command

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `OTEL_VERSION` |  | `-` |
| `OTEL_JAR_SHA256` |  | `-` |

## File: `../src/overlays/wireguard/docker-compose.yml`

### Service: wireguard

#### Image

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_VERSION` |  | `latest` |

#### Environment

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_SERVER_URL` |  | `auto` |
| `WIREGUARD_SERVER_PORT` |  | `51820` |
| `WIREGUARD_PEERS` |  | `laptop` |
| `WIREGUARD_INTERNAL_SUBNET` |  | `10.8.0.0` |
| `WIREGUARD_ALLOWED_IPS` |  | `0.0.0.0/0` |

#### Ports

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WIREGUARD_SERVER_PORT` |  | `51820` |

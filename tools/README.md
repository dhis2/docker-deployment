# Healthcheck Binary

Lightweight static binary for Docker container health checks. Works in minimal/distroless images that lack curl, wget, or bash.

## Source

The binary is from: <https://github.com/netroms/simple_healthcheck>

## Download at Runtime

The healthcheck binary is downloaded at container startup by the `healthcheck-init` service. This avoids storing large binary files in the repository.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARCH` | `amd64` | CPU architecture (`amd64` or `arm64`) |
| `HEALTHCHECK_VERSION` | `1.0.0` | Version to download |
| `HEALTHCHECK_SHA256_AMD64` | (see docker-compose.yml) | SHA256 for amd64 binary |
| `HEALTHCHECK_SHA256_ARM64` | (see docker-compose.yml) | SHA256 for arm64 binary |

The `ARCH` variable is auto-detected by `scripts/generate-env.sh`.

## Usage

```bash
healthcheck [options] <url>
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `-timeout` | 5s | Request timeout |
| `-status` | 200 | Expected HTTP status code (0 = accept any 2xx) |
| `-json-field` | | JSON field to check (dot notation) |
| `-json-value` | | Expected value for the JSON field |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Health check passed |
| 1 | Health check failed |

## Docker Compose Integration

The binary is downloaded to a volume and mounted into the DHIS2 container:

```yaml
healthcheck:
  test: [ "CMD", "/opt/dhis2/healthcheck-bin/healthcheck", "http://localhost:8080/api/ping" ]
```

## Updating

To update to a new version:

1. Find the latest release at <https://github.com/netroms/simple_healthcheck/releases>
2. Get the SHA256 checksums for both architectures
3. Update `HEALTHCHECK_VERSION` and the SHA256 variables in your `.env` file or docker-compose.yml

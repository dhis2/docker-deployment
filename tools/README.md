# Healthcheck Binaries

Lightweight static binaries for Docker container health checks. These work in minimal/distroless images that lack curl, wget, or bash.

## Source

These binaries are from: <https://github.com/netroms/simple_healthcheck>

## Binaries

| File | Architecture |
|------|--------------|
| `healthcheck-amd64` | Linux x86_64 (Intel/AMD) |
| `healthcheck-arm64` | Linux ARM64 (Apple Silicon, AWS Graviton) |

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

The binary is mounted into the DHIS2 container based on architecture:

```yaml
volumes:
  - ./tools/healthcheck-${ARCH:-amd64}:/opt/dhis2/healthcheck:ro

healthcheck:
  test: [ "CMD", "/opt/dhis2/healthcheck", "http://localhost:8080/api/ping" ]
```

The `ARCH` variable is auto-detected by `scripts/generate-env.sh`.

## Updating

To update the binaries, download the latest release from:
<https://github.com/netroms/simple_healthcheck/releases>

# Monitoring

The shared Grafana, Prometheus and Loki stack: what it collects, how to reach it, and what to configure.

One monitoring stack serves every instance on the host. It is started once and picks up instances as they are created, with no restart.

## Starting it

Part of the one-time host setup. It needs `stacks/monitoring/.env`, written by `make generate-stack-envs`.

```shell
COMPOSE_OPTS=-d make start-monitoring
```

`make clean-monitoring` stops it. Volumes persist, so collected metrics and logs survive a restart.

Starting it is optional. Instances run perfectly well without it — they still attach to the `monitoring` network, so nothing fails; Prometheus and Loki simply are not collecting, and the Loki log driver's pushes fail silently on their short timeout. Add it later at any time.

## What is collected

| Component         | Collects                                                                                                   |
|:--|:--|
| **Prometheus**    | Metrics from each instance's DHIS2 `/api/metrics` endpoint and its `postgres-exporter`, plus Traefik, the host and every container. |
| **Loki**          | Logs from every container — DHIS2, PostgreSQL, Traefik — pushed by the Docker Loki log driver.              |
| **Grafana**       | Queries both, with preloaded dashboards. The one user-facing component.                                    |
| **node-exporter** | Host-level CPU, memory, disk and network.                                                                  |
| **cAdvisor**      | Per-container resource usage.                                                                              |

DHIS2's own monitoring API is enabled on every instance, exposing JVM, database pool, Hibernate, uptime and CPU metrics alongside application metrics.

### Preloaded dashboards

Grafana comes provisioned with community dashboards for Traefik, PostgreSQL, node-exporter (host) and cAdvisor (containers). There is no DHIS2 application dashboard preloaded — the metrics are being collected and are queryable in Grafana, but you build or import the dashboard for them yourself.

## Reaching Grafana

Grafana is **not** published to the internet. It is served at `https://grafana.internal`, a hostname that resolves only inside the WireGuard tunnel.

1. Make sure the monitoring stack is running and the VPN is up (`make start-vpn`).
2. Connect to the VPN and install the internal certificate authority — see [VPN access](vpn.md).
3. Open `https://grafana.internal` and log in as `admin`, with `GRAFANA_ADMIN_PASSWORD` from `stacks/monitoring/.env`.

Change that password after your first login.

## How instances are discovered

`make start-instance` writes two Prometheus target files:

```text
stacks/monitoring/targets/dhis2/<name>.json       -> <name>-app:8080
stacks/monitoring/targets/postgres/<name>.json    -> <name>-postgres-exporter:9187
```

Prometheus watches those directories through file-based service discovery and begins scraping without a restart. `stop-instance` removes them and scraping stops. Both carry an `instance="<name>"` label, which is how metrics are separated per instance in Grafana. Loki applies the same label to logs.

### The shared monitoring credentials

Prometheus authenticates to each instance's DHIS2 metrics endpoint as a dedicated DHIS2 user, created by the `create-monitoring-user` job when an instance first starts.

Those credentials — `DHIS2_MONITOR_USERNAME` and `DHIS2_MONITOR_PASSWORD` — live in `stacks/monitoring/.env`, and `create-instance` copies them into each new instance's env file. **They must match across all instances**, since one Prometheus scrapes all of them with one set of credentials.

The practical consequence: if you regenerate `stacks/monitoring/.env`, every existing instance's env file is out of step and its DHIS2 targets go DOWN. Either keep the file, or regenerate all the instance env files with it.

## Configuration

Set in `stacks/monitoring/.env`:

| Variable                    | Default  | Purpose                                                              |
|:--|:--|:--|
| `GRAFANA_ADMIN_PASSWORD`    | Generated | Grafana admin login.                                                 |
| `DHIS2_MONITOR_USERNAME`    | `monitor` | DHIS2 user Prometheus scrapes as. Must match every instance.         |
| `DHIS2_MONITOR_PASSWORD`    | Generated | As above.                                                            |
| `PROMETHEUS_RETENTION_TIME` | `15d`     | How long metrics are kept.                                           |
| `LOKI_RETENTION_PERIOD`     | `744h`    | How long logs are kept — 31 days.                                    |
| `GRAFANA_VERSION` and others | Pinned   | Image versions for each component.                                   |

Retention is the setting to think about first: both defaults trade disk for history, and on a busy instance logs in particular can grow quickly. There is no alerting configured — no Alertmanager, no notification channels — so nothing tells you when something is wrong. Watching the dashboards, or wiring up your own alerting, is on you.

## The Loki log driver

Container logs reach Loki through a Docker plugin, which must be installed on the host. `make start-instance` and `make start-vpn` install it if it is missing; to do it by hand:

```shell
./scripts/install-loki-driver.sh
```

Because logs go to the driver rather than Docker's default json-file driver, `docker logs` output still works, but log rotation and retention are governed by Loki's settings rather than Docker's.

## See also

- [VPN access](vpn.md) — required to reach Grafana.
- [Profiling and APM](profiling.md) — Glowroot and Tempo tracing, which are per instance.
- [Architecture](architecture.md) — the networks involved.
- [Troubleshooting](troubleshooting.md) — targets showing DOWN, and other symptoms.

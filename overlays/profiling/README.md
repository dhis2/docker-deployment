# Profiling Overlay - Distributed Tracing with Grafana Tempo

This overlay adds distributed tracing capabilities to DHIS2 using Grafana Tempo and OpenTelemetry.

## Overview

The profiling overlay instruments the DHIS2 application with the OpenTelemetry Java Agent, enabling automatic tracing of:

- HTTP requests and responses
- Database queries (JDBC)
- Hibernate operations

Traces are collected by Grafana Tempo and can be visualized in Grafana, providing insights into performance bottlenecks and request flows.

## Prerequisites

The monitoring overlay must be enabled, as this overlay depends on Grafana for visualization.

## Deployment

```shell
docker compose -f docker-compose.yml -f overlays/monitoring/docker-compose.yml -f overlays/profiling/docker-compose.yml up
```

## Components

### Tempo

[Grafana Tempo](https://grafana.com/oss/tempo/) is a distributed tracing backend that stores and queries traces. It receives traces via OTLP (OpenTelemetry Protocol) and integrates seamlessly with Grafana.

### OpenTelemetry Java Agent

The [OpenTelemetry Java Agent](https://opentelemetry.io/docs/zero-code/java/agent/) automatically instruments the DHIS2 application without code changes. It attaches to the JVM and captures telemetry data.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TEMPO_VERSION` | `2.3.1` | Grafana Tempo version |
| `CURL_VERSION` | `8.10.1` | curl image version for downloading the agent |
| `OTEL_VERSION` | `2.11.0` | OpenTelemetry Java Agent version |
| `OTEL_JAR_SHA256` | (see docker-compose.yml) | SHA256 checksum for agent JAR verification |

### JAVA_TOOL_OPTIONS Override

> **Important:** This overlay overrides the `JAVA_TOOL_OPTIONS` environment variable.

Docker Compose overlays replace (not merge) environment variables. Therefore, this overlay includes the base `JAVA_TOOL_OPTIONS` configuration along with the OpenTelemetry agent settings:

```yaml
JAVA_TOOL_OPTIONS: >-
  -Dlog4j2.configurationFile=/opt/dhis2/log4j2.xml
  -javaagent:/otel/opentelemetry-javaagent.jar
  -Dotel.service.name=dhis2
  -Dotel.traces.exporter=otlp
  -Dotel.exporter.otlp.endpoint=http://tempo:4318
  -Dotel.metrics.exporter=none
  -Dotel.logs.exporter=none
  -Dotel.instrumentation.jdbc.enabled=true
  -Dotel.instrumentation.hibernate.enabled=true
```

If you need to add custom JVM options, modify this value in a local override file.

## Log Correlation

The `config/dhis2/log4j2.xml` configuration includes trace context (trace_id and span_id) in log output. This enables correlation between logs in Loki and traces in Tempo within Grafana.

## Viewing Traces

1. Open Grafana at `https://grafana.{APP_HOSTNAME}`
2. Navigate to **Explore**
3. Select **Tempo** as the data source
4. Search for traces by service name, trace ID, or duration

## Updating the OpenTelemetry Agent

To update to a new version:

1. Find the latest release at <https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases>
2. Download the JAR and compute its SHA256: `sha256sum opentelemetry-javaagent.jar`
3. Update `OTEL_VERSION` and `OTEL_JAR_SHA256` in your `.env` file or the docker-compose overlay

## Tempo default overrides

Those overrides were added to handle DHIS2's high trace volume. During testing, we hit this error:

```shell
LIVE_TRACES_EXCEEDED: max live traces exceeded for tenant single-tenant:
per-user traces limit (local: 10000 global: 0 actual local: 10000) exceeded
```

**Why DHIS2 generates so many traces:**

- The OpenTelemetry agent instruments *every* HTTP request, SQL query, and Hibernate operation
- DHIS2 startup alone runs hundreds of database migrations and initialization queries
- Each API request can trigger dozens of SQL queries, each becoming a span
- Background jobs (schedulers, analytics) continuously generate traces

**What each setting does:**

| Setting | Default | Our Value | Why |
|---------|---------|-----------|-----|
| `max_traces_per_user` | 10,000 | 100,000 | DHIS2 easily exceeds 10k concurrent traces during startup |
| `ingestion_rate_limit_bytes` | 15MB/s | 30MB/s | Higher throughput for trace data ingestion |
| `ingestion_burst_size_bytes` | 20MB | 50MB | Allow spikes during startup/heavy load |
| `max_bytes_per_trace` | 5MB | 50MB | Complex requests with many SQL queries can create large traces |
| `metrics_generator_processors` | none | service-graphs, span-metrics | Enables RED metrics and service dependency graphs in Grafana |

**For production**, you might want to tune these based on your actual usage, or add sampling to reduce trace volume:

```yaml
# In JAVA_TOOL_OPTIONS, add sampling to reduce volume:
-Dotel.traces.sampler=parentbased_traceidratio
-Dotel.traces.sampler.arg=0.1  # Sample 10% of traces
```

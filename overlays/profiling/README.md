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

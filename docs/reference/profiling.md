# Profiling and APM

Two performance tools run on every instance: Glowroot, a Java application performance monitor, and Tempo with the OpenTelemetry agent, for distributed request tracing.

> [!IMPORTANT]
> These are **always enabled**. Although both live under `overlays/`, `make start-instance` applies `overlays/profiling/` and `overlays/glowroot/` unconditionally — there is no flag to start an instance without them. That is worth knowing because it explains containers you did not ask for (`tempo`, `otel-init`, `glowroot-init`), a first start that needs GitHub access to download two agent JARs, and a JVM running with two Java agents attached.

To run without them you would have to invoke Compose directly rather than through `make start-instance`, which is outside what this deployment supports.

## Glowroot

[Glowroot](https://glowroot.org/) attaches to the DHIS2 JVM and records response times, slow traces, SQL queries and errors, with a UI for exploring them. It is the first place to look when DHIS2 is slow and you want to know which requests and which queries are responsible.

Reachable per instance, over the VPN only:

```text
https://<name>.glowroot.internal
```

So an instance named `prod` is at `https://prod.glowroot.internal`. The route is created by `start-instance` alongside the public one. Connect to the VPN and trust the internal certificate authority first — see [VPN access](vpn.md).

Glowroot's data lives in a per-instance `glowroot-data` volume and survives restarts. Configuration is in `overlays/glowroot/config/admin.json`.

> [!WARNING]
> Glowroot's UI has **no authentication** in this deployment. It is protected only by being unreachable outside the VPN. Anyone on the tunnel can read it, and it shows query text and request details — potentially including data. Treat VPN access as equivalent to read access to your instances' internals.

## Tracing with Tempo

The OpenTelemetry Java agent instruments the application automatically, with no code changes, capturing HTTP requests, JDBC queries and Hibernate operations as spans. Traces go to a Tempo instance and are explored in Grafana.

To view them: open Grafana at `https://grafana.internal`, go to **Explore**, select the **Tempo** data source, and search by service name, trace ID or duration. Log output includes trace and span IDs, so a log line in Loki can be followed to the trace it belongs to.

Tracing needs the monitoring stack running for Grafana to query Tempo. Without it, the instance's Tempo still runs and still collects — you just have nothing to read it with.

> [!NOTE]
> Every instance starts its own Tempo, and all of them join the shared `monitoring` network under the same `tempo` alias, which Docker DNS round-robins. When more than one instance is running, traces from one can be written to another's Tempo, so per-instance trace separation is not reliable.

### Trace volume

DHIS2 generates a very large number of spans: the agent instruments every request, SQL query and Hibernate operation, startup alone runs hundreds of migrations, and a single API call can produce dozens of spans. Tempo's default limits are raised substantially to cope, in `overlays/profiling/config/tempo/tempo.yml`.

For a production instance carrying real traffic, consider sampling rather than recording everything, by adding to `JAVA_TOOL_OPTIONS`:

```text
-Dotel.traces.sampler=parentbased_traceidratio
-Dotel.traces.sampler.arg=0.1     # keep 10% of traces
```

The cost of tracing everything is not only disk: two Java agents on a JVM add measurable overhead to every request, which matters when you are tuning a busy instance.

## Full configuration

[`overlays/profiling/README.md`](../../overlays/profiling/README.md) documents the tracing overlay in detail: version and checksum variables, the `JAVA_TOOL_OPTIONS` override and why it replaces rather than merges, log correlation, updating the agent, and each raised Tempo limit with its reasoning.

## See also

- [Monitoring](monitoring.md) — the shared metrics and logging stack.
- [VPN access](vpn.md) — required for both UIs.
- [PostgreSQL configuration](postgresql.md) — the slow query log, often a better first stop for database performance.

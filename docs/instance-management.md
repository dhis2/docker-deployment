# Instance Management Workflows

A collection of useful process and architectural reference diagrams.

## 1. One-time server setup

Run once per host before creating any instances.

```mermaid
%%{init: {"themeVariables": {"fontSize": "13px"}}}%%
flowchart TD
    A([Start]) --> B["make generate-stack-envs<br/>GEN_LETSENCRYPT_ACME_EMAIL=...<br/>GEN_GRAFANA_HOSTNAME=..."]
    B --> C["stacks/traefik/.env<br/>stacks/monitoring/.env written"]
    C --> D["make launch-traefik"]
    C --> E["make launch-monitoring"]
    D --> F["Creates: proxy network<br/>Creates: monitoring_net network<br/>Starts: Traefik container<br/>Watches: stacks/traefik/conf.d/"]
    E --> G["Writes: conf.d/monitoring.yml<br/>Starts: Grafana, Prometheus,<br/>Loki, etc.<br/>Watches: monitoring/targets/"]
```

## 8. Instance lifecycle (sequence)

```mermaid
sequenceDiagram
    actor Operator
    participant Make
    participant FS as instances/
    participant Docker
    participant Traefik
    participant Monitoring

    Note over Operator,FS: make create-instance
    Operator->>Make: APP_HOSTNAME=… PROJECT_NAME=NAME
    Make->>FS: generate instances/NAME.env
    Note right of FS: passwords + hostname set
    Make-->>Operator: instances/NAME.env created

    Note over Operator,Monitoring: make launch-instance
    Operator->>Make: PROJECT_NAME=NAME
    Make->>Docker: ensure proxy + monitoring_net networks
    Make->>Docker: create NAME-db network
    Make->>Docker: compose up postgres --wait
    Docker-->>Make: postgres healthy
    Make->>Traefik: write conf.d/NAME.yml
    Note right of Traefik: hot-reloads route immediately
    Make->>Monitoring: write targets/dhis2/NAME.json
    Make->>Monitoring: write targets/postgres/NAME.json
    Note right of Monitoring: picks up new scrape targets
    Make->>Docker: compose up app
    Docker-->>Operator: Running at NAME hostname


    Note over Operator,Monitoring: make stop-instance
    Operator->>Make: PROJECT_NAME=NAME
    Make->>Docker: compose down app + overlays
    Make->>Docker: postgres compose down
    Make->>Docker: remove NAME-db network
    Make->>Traefik: remove conf.d/NAME.yml
    Note right of Traefik: deregisters route
    Make->>Monitoring: remove targets/NAME.json
    Note right of Monitoring: stops scraping
    Make-->>Operator: Instance stopped (env file retained)

    Note over Operator,FS: make delete-instance (planned)
    Operator->>Make: PROJECT_NAME=NAME
    Make->>FS: remove instances/NAME.env
    Make-->>Operator: Instance fully removed

```

## Network architecture

### Docker network membership

![Architecture](./architecture.svg)

| Service | proxy | monitoring_net | one-db | two-db |
|---|:---:|:---:|:---:|:---:|
| Traefik | ✓ | | | |
| one-app | ✓ | ✓ | ✓ | |
| two-app | ✓ | ✓ | | ✓ |
| one-postgres + exporter | | ✓ | ✓ | |
| two-postgres + exporter | | ✓ | | ✓ |
| Prometheus | | ✓ | | |
| Grafana | | ✓ | | |
| Loki | | ✓ | | |

### Generating the architecture SVG

The D2 source is at [`docs/architecture.d2`](./architecture.d2). It uses the [ELK](https://eclipse.dev/elk/) layout engine for cleaner routing of dense graphs.

#### Install D2

```bash
# macOS
brew install d2

# Linux / WSL
curl -fsSL https://d2lang.com/install.sh | sh
```

#### Generate the SVG

> **Note:** the DHIS2 CLI is also named `d2` and shadows the diagram tool in `$PATH`.
> Use the full path, or add an alias: `alias d2diagram=~/.local/bin/d2`

```bash
~/.local/bin/d2 docs/architecture.d2 docs/architecture.svg

```

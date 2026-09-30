# PostgreSQL configuration

How the database is configured per instance, and what to tune.

The image is [PostGIS](https://hub.docker.com/r/postgis/postgis), pinned by `POSTGRES_VERSION` in the instance env file. DHIS2 requires the PostGIS extension, along with `pg_trgm` and `btree_gin`, all of which are created for you.

> [!IMPORTANT]
> The defaults shipped here are **not tuned for your hardware**. They assume roughly 8 GB of RAM available to the database and will be wrong — in one direction or the other — on most machines. Tuning PostgreSQL is one of the biggest levers on DHIS2 performance, and one of the areas where this deployment is still immature.

## Where the configuration lives

`create-instance` copies the shared defaults from `config/postgresql/` into `instances/<name>/postgresql/`, so each instance is tuned independently. Edit the per-instance copy:

```text
instances/<name>/postgresql/
├── postgresql.conf        # do not edit: sets listen_addresses and includes conf.d
└── conf.d/
    ├── 10-memory.conf
    ├── 20-connections.conf
    └── 30-logging.conf
```

`postgresql.conf` exists only to include `conf.d/`. Put your settings in files under `conf.d/`, where later files win over earlier ones by numeric prefix. **Add a new file** rather than editing the shipped ones — `40-tuning.conf`, say — so your changes stay separate from the defaults and survive an update to them.

Editing `config/postgresql/` instead affects only instances you create *afterwards*.

## Applying a change

Most settings need the container restarted:

```shell
PROJECT_NAME=<name> make stop-instance
COMPOSE_OPTS=-d PROJECT_NAME=<name> make start-instance
```

Settings that PostgreSQL can reload without a restart — most logging settings, for instance — can be applied in place:

```shell
sudo docker compose --project-name <name> --env-file instances/<name>/.env \
  -f stacks/postgres/docker-compose.yml exec database \
  psql -U postgres -c 'SELECT pg_reload_conf();'
```

`shared_buffers` and `max_connections` are **not** reloadable and always need a restart. `SHOW <setting>;` tells you what the server is actually running with, which is the quickest way to confirm a change landed.

## What is set by default

### Memory — `10-memory.conf`

```conf
shared_buffers = 2GB        # usually 25-40% of RAM
work_mem = 16MB             # memory per sort/hash operation
maintenance_work_mem = 128MB
effective_cache_size = 6GB  # usually ~75% of RAM
```

The two to get right first:

- **`shared_buffers`** — PostgreSQL's own cache. 25–40% of the RAM available to the database. Too high starves the operating system's cache and can make things slower, not faster.
- **`effective_cache_size`** — not an allocation, but an estimate of total cache available, used by the query planner. Around 75% of RAM.

**`work_mem` is per operation, not per connection.** A single query with several sorts or hash joins can use it several times over, and with `max_connections = 200` the worst case is far more memory than most machines have. Raise it cautiously, or raise it for a single session when running a heavy report rather than globally.

DHIS2 analytics generation is the most memory-hungry thing the database does; `maintenance_work_mem` matters there, and can be raised temporarily for a large analytics run.

### Connections — `20-connections.conf`

```conf
max_connections = 200
superuser_reserved_connections = 3
```

This has to be at least as large as DHIS2's connection pool, set in `instances/<name>/dhis2/dhis.conf`. If the pool can open more connections than PostgreSQL allows, DHIS2 fails at load rather than gracefully. Each connection costs memory, so do not raise this "just in case" — a pool sized to the hardware beats a large pool that thrashes.

### Logging — `30-logging.conf`

```conf
log_destination = 'stderr'
logging_collector = off            # disable writing to files
log_statement = 'none'             # or 'all' if you want full query logging
log_min_duration_statement = 500   # log queries slower than 500ms
log_timezone = 'UTC'
```

Logs go to stderr and from there to the Docker Loki driver, so they are queryable in Grafana alongside everything else. `logging_collector` is deliberately off: writing log files inside the container would mean they are neither collected nor rotated.

The slow query log at 500 ms is the single most useful diagnostic here when DHIS2 feels slow. `log_statement = 'all'` logs everything, which is occasionally invaluable and otherwise a way to fill a disk.

## Tuning it for real

Start from a tool that accounts for your hardware and workload — [PGTune](https://pgtune.leopard.in.ua/) is a reasonable baseline, choosing a "Data warehouse" profile, since DHIS2's analytics workload resembles one more than it does a transactional application. Write the result into a new `conf.d/40-tuning.conf` and restart.

Then measure rather than guess: the PostgreSQL dashboard in Grafana, the slow query log, and `pg_stat_statements` if you enable it. Cache hit ratios, connection counts and slow queries will tell you what to change next more reliably than a settings calculator will.

Also worth knowing: no CPU or memory limits are applied to containers, so a database configured to use more memory than the host has will not be constrained by Docker — it will be killed by the kernel, or take the host down with it.

## Reaching the database directly

The database is not published to the host. It is on the instance's own `<name>-db` network, reachable only from that instance's containers. For a `psql` session:

```shell
sudo docker compose --project-name <name> --env-file instances/<name>/.env \
  -f stacks/postgres/docker-compose.yml exec database \
  psql -U postgres -d dhis
```

Credentials are in `instances/<name>/.env`. Direct database access is powerful and unguarded — `dhis` is the application's own schema, and changing it by hand is a good way to corrupt an instance. Take a backup first.

## See also

- [Environment variables](environment-variables.md) — the database service's variables.
- [Backup and restore](backup-restore.md).
- [Monitoring](monitoring.md) — the PostgreSQL dashboard and exporter.

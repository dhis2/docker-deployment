# PostgreSQL configuration

How the database is configured per instance, and what to tune.

The image is [PostGIS](https://hub.docker.com/r/postgis/postgis), pinned by `POSTGRES_VERSION` in the instance env file. DHIS2 requires the PostGIS extension, along with `pg_trgm` and `btree_gin`, all of which are created for you.

> [!IMPORTANT]
> The defaults shipped here are **not tuned for your hardware**. They assume roughly 8 GB of RAM available to the database and will be wrong — in one direction or the other — on most machines. Tuning PostgreSQL is one of the biggest levers on DHIS2 performance, and one of the areas where this deployment is still immature.

## Where the configuration lives

`create-instance` copies the shared defaults from `config/postgresql/` into `instances/<name>/postgresql/`, so each instance is tuned independently. Edit the per-instance copy:

```text
instances/<name>/postgresql/
├── postgresql.conf        # do not edit: settings DHIS2 requires, then includes conf.d
├── pg_hba.conf            # client authentication: who may connect, and how
└── conf.d/
    ├── 10-memory.conf
    ├── 20-connections.conf
    ├── 30-logging.conf
    └── 35-wal.conf
```

`postgresql.conf` holds the settings DHIS2 depends on, then includes `conf.d/`, so `conf.d/` can still override it. PostgreSQL reads `conf.d/` in file name order and later files win. The shipped files are numbered below 40, so **add your own file numbered 40 or higher** — `40-tuning.conf`, say — rather than editing the shipped ones. It then overrides the defaults and survives an update to them.

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

### Edit `postgresql.conf` and `pg_hba.conf` in place

Both are bind-mounted as single files, and a single-file mount follows the inode, not the name. Tools that save by writing a new file and renaming it over the old one, such as `sed -i` or vim without `backupcopy=yes`, leave the container on the old inode:

- **Linux host:** the container keeps reading the old content. A reload logs only `received SIGHUP, reloading configuration files` and changes nothing.
- **Docker Desktop:** the file disappears from the container and the reload logs `No such file or directory`. The server keeps its current configuration.

Edit in place instead: append with `>>`, or `cp` the new content over the file. If the file may have been replaced, restart the instance as above to recreate the container. `make start-postgres` alone does nothing, since the running container is unchanged.

`conf.d/` is a directory mount and is not affected.

## What is set by default

### Required by DHIS2 — `postgresql.conf`

```conf
listen_addresses = '*'
jit = off
max_locks_per_transaction = 128
```

- **`listen_addresses`** — the application, exporter and backup containers connect over TCP on the instance's `<name>-db` network. No port is published to the host; see [reaching the database directly](#reaching-the-database-directly).
- **`jit = off`** — JIT compilation slows down the queries DHIS2 generates for program indicators.
- **`max_locks_per_transaction = 128`** — DHIS2's Flyway migrations touch many tables in one transaction and can fail with `out of shared memory` at the default of 64. Needs a restart.

### Memory — `10-memory.conf`

```conf
shared_buffers = 2GB        # usually 25-40% of RAM
work_mem = 16MB             # memory per sort/hash operation
maintenance_work_mem = 128MB
effective_cache_size = 6GB  # usually ~75% of RAM
random_page_cost = 1.1      # locally attached SSD/NVMe
```

The two to get right first:

- **`shared_buffers`** — PostgreSQL's own cache. 25–40% of the RAM available to the database. Too high starves the operating system's cache and can make things slower, not faster.
- **`effective_cache_size`** — not an allocation, but an estimate of total cache available, used by the query planner. Around 75% of RAM.

**`work_mem` is per operation, not per connection.** A single query with several sorts or hash joins can use it several times over, and with `max_connections = 200` the worst case is far more memory than most machines have. Raise it cautiously, or raise it for a single session when running a heavy report rather than globally.

DHIS2 analytics generation is the most memory-hungry thing the database does; `maintenance_work_mem` matters there, and can be raised temporarily for a large analytics run.

**`random_page_cost = 1.1`** suits locally attached SSD or NVMe storage, where random reads cost about the same as sequential ones, and makes the planner more willing to use indexes. On spinning disks or network storage, raise it towards the default of `4.0`.

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
log_min_duration_statement = 300s  # log queries slower than 5 minutes
log_timezone = 'UTC'
```

Logs go to stderr and from there to the Docker Loki driver, so they are queryable in Grafana alongside everything else. `logging_collector` is deliberately off: writing log files inside the container would mean they are neither collected nor rotated.

The slow query log is the most useful diagnostic when DHIS2 feels slow. Its threshold is high on purpose: analytics and program indicator queries of several seconds to a minute are normal, so a few hundred milliseconds would flood the log, while a query over five minutes is worth looking at. Lower it temporarily when investigating; it is reloadable. Logged statements include their literal values, which can be health data.

`log_statement = 'all'` logs everything, which is occasionally invaluable and otherwise a way to fill a disk.

### Write-ahead log — `35-wal.conf`

```conf
synchronous_commit = off
```

This trades durability for commit throughput: a commit is reported before its WAL reaches disk, and the WAL writer flushes it shortly after. It is reloadable.

> [!WARNING]
> With `synchronous_commit = off`, a commit is reported before it reaches disk. A crash of PostgreSQL or the host, including an out-of-memory kill, loses the transactions committed in the last three `wal_writer_delay` intervals: **about 0.6 seconds** at the default of 200 ms. The database is not corrupted; those transactions are gone. A clean shutdown loses nothing. The database service allows two minutes for one (`stop_grace_period`); if Docker kills the container after that, it counts as a crash. If losing those transactions is unacceptable, set `synchronous_commit = on` in your own `conf.d/` file.

## Tuning it for real

Start from a tool that accounts for your hardware and workload — [PGTune](https://pgtune.leopard.in.ua/) is a reasonable baseline, choosing a "Data warehouse" profile, since DHIS2's analytics workload resembles one more than it does a transactional application. Write the result into a new `conf.d/40-tuning.conf` and restart. PGTune also sets `random_page_cost`; your file is read last, so its value wins.

Then measure rather than guess: the PostgreSQL dashboard in Grafana, the slow query log, and `pg_stat_statements` if you enable it. Cache hit ratios, connection counts and slow queries will tell you what to change next more reliably than a settings calculator will.

Also worth knowing: no CPU or memory limits are applied to containers, so a database configured to use more memory than the host has will not be constrained by Docker — it will be killed by the kernel, or take the host down with it.

## Client authentication — `pg_hba.conf`

`instances/<name>/postgresql/pg_hba.conf` controls who can connect and how. It is mounted at `/etc/postgresql/pg_hba.conf` and the server's `hba_file` points at it; the copy `initdb` writes into the data directory is not used. `SHOW hba_file;` confirms which file is in use.

| Connection         | Database             | Method          |
|:--|:--|:--|
| Unix domain socket | all, and replication | `trust`         |
| TCP, any address   | all                  | `scram-sha-256` |

**Socket.** `trust` lets `psql` inside the container connect without a password. The socket is on a tmpfs inside the container and is not published, so using it requires `exec` into the container, which already means root-equivalent access to Docker. Anyone with that access can connect as any role.

**TCP.** The application, `postgres-exporter`, and the backup, restore and admin-password containers connect over TCP with a password. The rule accepts any source address, but the database publishes no port and is only on the `<name>-db` network. Exposing it further is a Compose change (a published port or another network); narrow the address range here before doing that.

**Replication.** `all` does not match physical replication, so it has its own socket rule. Over TCP there is none: a standby needs its own `host replication` rule. Logical replication names a database and is matched by the ordinary rules.

Changes apply on a [reload](#applying-a-change), provided the file was [edited in place](#edit-postgresqlconf-and-pg_hbaconf-in-place).

`POSTGRES_INITDB_ARGS` in `stacks/postgres/docker-compose.yml` still sets `--auth-host` and `--auth-local`. They only affect the unused data directory copy.

Instances created before `pg_hba.conf` was added don't have it, and `make start-postgres` refuses to start them until it is copied in. See [troubleshooting](troubleshooting.md#pg_hbaconf-is-missing-or-postgresql-fails-with-is-a-directory).

## Reaching the database directly

The database is not published to the host. It is on the instance's own `<name>-db` network, reachable only from that instance's containers. For a `psql` session:

```shell
sudo docker compose --project-name <name> --env-file instances/<name>/.env \
  -f stacks/postgres/docker-compose.yml exec database \
  psql -U postgres -d dhis
```

This uses the container's Unix socket, so no password is needed; the credentials in `instances/<name>/.env` are for TCP connections. Direct database access is powerful and unguarded — `dhis` is the application's own schema, and changing it by hand is a good way to corrupt an instance. Take a backup first.

## See also

- [Environment variables](environment-variables.md) — the database service's variables.
- [Backup and restore](backup-restore.md).
- [Monitoring](monitoring.md) — the PostgreSQL dashboard and exporter.

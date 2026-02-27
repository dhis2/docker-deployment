# Read Replica Overlay

This overlay adds a PostgreSQL streaming read replica to the deployment. DHIS2 will
use the replica for read-only analytics queries, reducing load on the primary database.

## How it works

1. **Primary database** is configured for replication (WAL settings, replication user,
   `pg_hba.conf` entry).
2. **`replica-init`** runs `pg_basebackup` to create a full copy of the primary (only on first run; subsequent starts skip this step).
3. **`database-replica`** starts PostgreSQL in hot-standby mode, continuously streaming WAL from the primary.
4. **DHIS2** is configured with a `read1.connection.*` pointing at the replica.

## Prerequisites

* The primary database must be freshly initialised **or** you must manually create the replication user and `pg_hba.conf` entry on an existing primary (the init script only runs on first database creation).

## Environment variables

| Variable | Description | Default |
|---|---|---|
| `POSTGRES_REPLICATION_USERNAME` | Replication user on the primary | `replication` |
| `POSTGRES_REPLICATION_PASSWORD` | Password for the replication user | *(required)* |

These are included in `.env.template` and generated automatically by
`scripts/generate-env.sh`.

## Usage

Include the overlay when starting the stack:

```bash
docker compose -f docker-compose.yml -f overlays/read-replica/docker-compose.yml up -d
```

## Re-initialising the replica

After a database restore, the replica's WAL stream will be invalid and it must be
rebuilt from scratch. Use the `reinit-replica` service (which has the `restore` profile):

```bash
docker compose stop database-replica
docker compose run --rm reinit-replica
docker compose start database-replica
```

If you are using the `restore-database` Makefile target you should run the
reinitialisation immediately after the restore completes and before restarting `app`.

To reinitialise for any other reason (e.g. replica has fallen too far behind):

```bash
docker compose stop database-replica
docker compose run --rm reinit-replica
docker compose start database-replica
```

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Service definitions for the replica and primary overrides |
| `config/dhis2/dhis.conf` | DHIS2 configuration with `read1.connection.*` settings |
| `scripts/create-replication-user.sh` | Init script that creates the replication user on the primary |
| `scripts/replica-entrypoint.sh` | Entrypoint that runs `pg_basebackup` on first start |

> **Note:** The PostgreSQL WAL and hot-standby settings live in
> `config/postgresql/conf.d/40-replication.conf` (base config directory) since they are
> harmless without a replica and cannot be overlay-mounted into the read-only container.
| `scripts/replica-entrypoint.sh` | Entrypoint that runs `pg_basebackup` on first start |

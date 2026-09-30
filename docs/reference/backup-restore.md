# Backup and restore

Backing up and restoring an instance's database and file storage, and loading a dump from elsewhere.

Every command needs `PROJECT_NAME` to say which instance it applies to. Files are read from and written to `backups/<PROJECT_NAME>/`, which is mounted into the backup containers as `/backups`.

## Backing up

```shell
PROJECT_NAME=<name> make backup
```

That runs both halves. Either can be run alone:

```shell
PROJECT_NAME=<name> make backup-database
PROJECT_NAME=<name> make backup-file-storage
```

Both produce files under `backups/<name>/`, named with a UTC timestamp in the form `YYYY-MM-DD_HH-MM-SS_UTC`:

| What          | Produces                                     |
|:--|:--|
| Database      | `<timestamp>.pgc` or `<timestamp>.sql.gz`    |
| File storage  | `file-storage-<timestamp>/`                  |

Backups run against a **running** instance; neither target stops the application.

> [!IMPORTANT]
> **Analytics tables are excluded from database backups** — both the `analytics_*` and `_*` table families are skipped, because they are derived data that DHIS2 regenerates and they can be larger than the rest of the database put together. A restored instance therefore has no analytics until you run analytics generation, so dashboards and pivot tables will be empty until you do. Run it from *Data Administration → Analytics Tables*, or through `POST /api/resourceTables/analytics`, after any restore.

### Formats

`POSTGRES_BACKUP_FORMAT` selects the database dump format:

| Value              | Extension  | Notes                                                                                                     |
|:--|:--|:--|
| `custom` (default) | `.pgc`     | PostgreSQL's compressed custom format. Restores in parallel, so it is faster on a large database.         |
| `plain`            | `.sql.gz`  | Gzipped SQL. Readable and greppable, portable to any PostgreSQL, but restores single-threaded.            |

```shell
PROJECT_NAME=<name> POSTGRES_BACKUP_FORMAT=plain make backup-database
```

See the [`pg_dump` documentation](https://www.postgresql.org/docs/current/app-pgdump.html) for what the formats imply.

### Naming a backup yourself

Set `BACKUP_TIMESTAMP` to replace the generated timestamp — useful for a named checkpoint you intend to keep:

```shell
PROJECT_NAME=<name> BACKUP_TIMESTAMP=before-43-upgrade make backup
```

That yields `before-43-upgrade.pgc` and `file-storage-before-43-upgrade/`. Setting it on `make backup` keeps the database and file storage halves in step, which matters because they are written by separate containers.

`make get-backup-timestamp` prints the timestamp that would be generated now.

## Restoring

Restoring **replaces** the target instance's data. On a live instance this is destructive and not reversible; take a backup first.

Both restore targets stop the application, restore, and start it again. The database stays up throughout.

```shell
# Database only
PROJECT_NAME=<name> DB_RESTORE_FILE=<file> make restore-database

# File storage only
PROJECT_NAME=<name> FILE_STORAGE_RESTORE_SOURCE_DIR=<dir> make restore-file-storage

# Both
PROJECT_NAME=<name> \
  DB_RESTORE_FILE=<file> \
  FILE_STORAGE_RESTORE_SOURCE_DIR=<dir> \
  make restore
```

Both variables are paths **relative to `backups/<PROJECT_NAME>/`**, not to the repository. Pass `2026-01-15_02-30-00_UTC.pgc`, not `backups/prod/2026-01-15_02-30-00_UTC.pgc`.

Accepted database formats are `.sql.gz` and `.pgc`, chosen by file extension. Renaming a file to match an extension does not convert it; the restore will fail partway.

### Re-apply the admin password afterwards

A dump carries its own user accounts, including `admin`, which replace the ones in the instance you restored into. Run `start-instance` afterwards to re-apply the password from your env file:

```shell
PROJECT_NAME=<name> make start-instance
```

That re-runs the `update-admin-password` job, after which `admin` uses `DHIS2_ADMIN_PASSWORD` from `instances/<name>/.env` again. Skip it if you would rather use the credentials that came with the dump.

### What a database restore does

Worth knowing, because it explains which dumps work and which do not:

1. Waits for PostgreSQL to accept connections.
2. Drops the `public` schema and recreates it, then creates the `postgis`, `pg_trgm` and `btree_gin` extensions.
3. Streams the dump in. For `.sql.gz`, `ALTER ... OWNER`, `GRANT` and `REVOKE` statements are filtered out, so a dump created under different role names still loads. For `.pgc`, `pg_restore` runs with `--no-owner --no-acl`, in parallel (`DB_RESTORE_NUMBER_OF_JOBS`, default 4).
4. Re-applies ownership of everything to the instance's own database user.

The consequence is that dumps from other DHIS2 deployments load without the role and permission wrangling that usually accompanies moving a PostgreSQL database between servers.

## Loading a demo or migration dump

The same machinery loads a dump that this deployment did not create. Put the file in the instance's backup directory and restore it by name:

```shell
mkdir -p backups/<name>
curl -L -o backups/<name>/demo.sql.gz \
  https://databases.dhis2.org/sierra-leone/2.43/dhis2-db-sierra-leone.sql.gz
PROJECT_NAME=<name> DB_RESTORE_FILE=demo.sql.gz make restore-database
PROJECT_NAME=<name> make start-instance
```

> [!IMPORTANT]
> **The dump's DHIS2 version must match `DHIS2_VERSION`.** DHIS2 migrates its schema forward on startup, so a dump from an older version is upgraded for you, but a dump from a **newer** version cannot be migrated backwards and the application will fail to start. Check both before restoring.

Browse <https://databases.dhis2.org/> for the demo databases available per version. The [demo environment guide](../guides/demo-environment.md) walks through this end to end.

## Making it a real backup strategy

The `make` targets are the mechanism, not the strategy. Three things are yours to arrange:

**Schedule it.** Nothing in this repository runs backups on a timer. A cron entry on the host:

```cron
30 2 * * * cd /opt/dhis2 && PROJECT_NAME=prod make backup >> /var/log/dhis2-backup.log 2>&1
```

**Get the files off the host.** A backup on the same disk as the database does not protect you against losing that disk, and it does nothing at all against the host being lost. Sync `backups/` to object storage or another machine, and remember those files contain all of your data — encrypt them and control who can read them.

**Test a restore.** Restore into a throwaway instance and confirm the data is there, before you need it. The [test environment guide](../guides/test-environment.md) covers standing one up. A backup you have never restored is a guess.

Old backups are not pruned, so the directory grows until you deal with it.

## See also

- [Instance lifecycle](instance-lifecycle.md) — the surrounding targets.
- [Environment variables](environment-variables.md) — the backup and restore services' variables.
- [Troubleshooting](troubleshooting.md) — restore failures and what they mean.

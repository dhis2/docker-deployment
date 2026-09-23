# DHIS2 versions and upgrades

Which DHIS2 version an instance runs, how to choose it, and how to move to a different one.

## Setting the version

`DHIS2_VERSION` in `instances/<name>/.env` is the image tag for the [`dhis2/core`](https://hub.docker.com/r/dhis2/core/tags) image. It is per instance, so instances on the same host can run different versions.

```dotenv
DHIS2_VERSION=43.0.0
```

The tag forms available, and what each means for you:

| Form                       | Example                     | Resolves to                                                    |
|:--|:--|:--|
| Full version               | `43.0.0`                    | Exactly that patch release, and never moves.                   |
| Minor line                 | `43.0`                      | The latest patch of that minor line.                           |
| Major line                 | `43`                        | The latest patch of that major line.                           |
| Prefixed equivalents       | `2.43`, `2.43.1`            | The same images; the `2.` prefix is kept for historical reasons. |
| Release candidate          | `43.0.0-rc`                 | A pre-release build. Not for production.                       |
| Timestamped build          | `42.6.0-20260826T150401Z`   | One specific build, pinned harder than a version tag.          |

The shorter the tag, the more it moves under you. `43` picks up new patches whenever you pull; `43.0.0` never changes.

## The default, and why to change it

If `DHIS2_VERSION` is unset, both `.env.template` and `docker-compose.yml` fall back to `43`.

> [!IMPORTANT]
> That default is a **literal in the repository**, not a pointer to whatever is newest. It was the latest stable release line when it was last set, and it ages: once a later version ships, the default quietly means "the latest patch of an older release." Always set `DHIS2_VERSION` to the version you actually intend to run rather than relying on the default, and check it before a first start rather than after.

For a deployment carrying real data, **pin the full version** — `43.0.0`, not `43`. Otherwise the version you are running changes the next time the image is pulled, which turns an upgrade into something that happens to you rather than something you decided to do. Pinning means upgrades are deliberate, reproducible, and happen when you have a backup and time to check the result.

Tracking a major line like `43` is reasonable for a [test](../guides/test-environment.md) or [demo](../guides/demo-environment.md) instance, where picking up the newest patch automatically is convenient and nothing is lost if it surprises you.

## Upgrading

DHIS2 migrates its own database on startup, so an upgrade is: point the instance at a newer image and start it. The deployment does not need reconfiguring.

> [!WARNING]
> **The database migration is not reversible.** DHIS2 migrates schemas forward only; there is no downgrade. A backup taken before the upgrade is the only way back, so take one and confirm it exists before you start.

```shell
# 1. Back up, and name the backup after what you are about to do
PROJECT_NAME=<name> BACKUP_TIMESTAMP=before-44-upgrade make backup

# 2. Stop the instance
PROJECT_NAME=<name> make stop-instance

# 3. Edit instances/<name>/.env and set the new DHIS2_VERSION

# 4. Start it again — the new image is pulled and the migration runs
COMPOSE_OPTS=-d PROJECT_NAME=<name> make start-instance
```

Then watch the application log until the migration finishes and the instance becomes healthy:

```shell
sudo docker compose --project-name <name> --env-file instances/<name>/.env logs -f app
```

**Verify:** the log shows Flyway migrations applied without error, the container becomes healthy, and you can log in. Migrations on a large database can take considerably longer than a normal start, so give it time before assuming it has hung.

Afterwards, **regenerate analytics** — *Data Administration → Analytics Tables*, or `POST /api/resourceTables/analytics`. A major upgrade can change how analytics tables are built, and until they are regenerated dashboards may be stale or empty.

### Before you upgrade, understand what the upgrade needs

Read the release notes for the target version **and for every release between yours and it**. Skipping versions is fine — going straight from 40 to 43 is a perfectly normal upgrade — but the requirements accumulate: an intermediate release may have changed a configuration setting, required a minimum PostgreSQL or Java version, deprecated an API your integrations use, or needed a manual metadata step. Those requirements still apply even when you pass through that version in a single jump.

What matters is that you can say what the upgrade requires of *your* instance, from *your* current version to the target, before you start it. Release notes and upgrade documentation are on [docs.dhis2.org](https://docs.dhis2.org).

Rehearse it first where possible. Restore a copy of your production database into a throwaway instance on your current version, upgrade that, and see what happens — the [test environment guide](../guides/test-environment.md) covers standing one up. That converts an upgrade from a hope into something you have already watched succeed.

### When the tag has not changed

Compose pulls an image it does not have locally, so changing `DHIS2_VERSION` to a new tag pulls the new image automatically. It does **not** re-check a tag it already has: if you track a moving tag like `43` and a new patch is published upstream, restarting keeps running your cached image. Pull explicitly to pick it up:

```shell
sudo docker compose --project-name <name> --env-file instances/<name>/.env pull app
COMPOSE_OPTS=-d PROJECT_NAME=<name> make start-instance
```

This is the other reason to pin full versions: with `43.0.0` there is no ambiguity about which image is running, and `docker compose images` tells you the truth either way.

### Downgrading

You cannot. Once the database has been migrated, an older DHIS2 will refuse to start against it. The route back is to restore the backup you took before the upgrade, into an instance running the old version — see [backup and restore](backup-restore.md).

## Where the version has to match something else

| Situation                        | Requirement                                                                                       |
|:--|:--|
| Restoring a dump                 | The dump's version must be the same as or **older** than `DHIS2_VERSION`. Newer fails to migrate. |
| Loading a demo database          | Pick the dump published for your version from <https://databases.dhis2.org/>.                     |
| PostgreSQL                       | `POSTGRES_VERSION` is set in the same env file. Check the target DHIS2 release's requirements.     |

## See also

- [Instance lifecycle](instance-lifecycle.md) — what `stop-instance` and `start-instance` change.
- [Backup and restore](backup-restore.md) — take one before every upgrade.
- [Environment variables](environment-variables.md) — generated from the compose files.
- [Troubleshooting](troubleshooting.md) — migration errors and instances that will not start.

#!/usr/bin/env bash

set -o errexit
set -o pipefail

if [ "$POSTGRES_BACKUP_FORMAT" = "plain" ]; then
  time (pg_dump --host "$POSTGRES_HOST" --username "$POSTGRES_USER" --format plain --exclude-table "analytics_*" --exclude-table "_*" "$POSTGRES_DB" --verbose | gzip > "/backups/$BACKUP_TIMESTAMP.sql.gz")
else
  time pg_dump --host "$POSTGRES_HOST" --username "$POSTGRES_USER" --format "$POSTGRES_BACKUP_FORMAT" --exclude-table "analytics_*" --exclude-table "_*" --file "/backups/$BACKUP_TIMESTAMP.pgc" "$POSTGRES_DB" --verbose
fi

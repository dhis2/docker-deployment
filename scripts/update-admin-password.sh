#!/bin/sh

set -o errexit
set -o nounset

# Hash with pgcrypto inside a rolled-back transaction so the extension is not
# left behind in the DHIS2 database, then update the user and report the row count.
export PGPASSWORD="$POSTGRES_PASSWORD"
UPDATED=$(psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" \
  --quiet --tuples-only --no-align --no-psqlrc \
  --set ON_ERROR_STOP=1 \
  --set username="$DHIS2_ADMIN_USERNAME" \
  --set password="$DHIS2_ADMIN_PASSWORD" <<'SQL'
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT crypt(:'password', gen_salt('bf', 10)) AS hash \gset
ROLLBACK;
WITH updated AS (
  UPDATE "userinfo" SET "password" = :'hash' WHERE "username" = :'username' RETURNING 1
)
SELECT count(*) FROM updated;
SQL
)

if [ "$UPDATED" != 1 ]; then
  echo "Error: expected to update 1 user named '$DHIS2_ADMIN_USERNAME', updated $UPDATED" >&2
  exit 1
fi

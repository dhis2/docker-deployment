#!/bin/sh

set -o errexit
set -o nounset

# Hash with pgcrypto in the maintenance database, inside a rolled-back
# transaction, as pgcrypto clashes with DHIS2's own gen_random_uuid().
# Then update the user in the DHIS2 database and report the row count.
export PGPASSWORD="$POSTGRES_PASSWORD"
UPDATED=$(psql --host "$POSTGRES_HOST" --username postgres --dbname postgres \
  --quiet --tuples-only --no-align --no-psqlrc \
  --set ON_ERROR_STOP=1 \
  --set dbname="$POSTGRES_DB" \
  --set username="$DHIS2_ADMIN_USERNAME" \
  --set password="$DHIS2_ADMIN_PASSWORD" <<'SQL'
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT crypt(:'password', gen_salt('bf', 10)) AS hash \gset
ROLLBACK;
\connect :dbname
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

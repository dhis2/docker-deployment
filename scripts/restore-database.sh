#!/usr/bin/env bash

set -o errexit

if [ -z "$DB_RESTORE_FILE" ]; then
  echo "Error: DB_RESTORE_FILE environment variable must be set"
  exit 1
fi

if [ ! -f "/backups/$DB_RESTORE_FILE" ]; then
  echo "Error: Restore file /backups/$DB_RESTORE_FILE not found"
  exit 1
fi

echo "Restoring database from $DB_RESTORE_FILE"

echo "Waiting for database to be ready..."
until pg_isready --host "$POSTGRES_HOST" --username "$POSTGRES_USER"; do
  sleep 2
done

psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" <<EOF
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT USAGE ON SCHEMA public TO public;
GRANT CREATE ON SCHEMA public TO public;
EOF

if echo "$DB_RESTORE_FILE" | grep --quiet "\\.sql\\.gz$"; then
  gunzip --stdout "/backups/$DB_RESTORE_FILE" \
    | grep --invert-match --ignore-case 'ALTER .* OWNER' \
    | grep --invert-match --ignore-case 'GRANT ' \
    | grep --invert-match --ignore-case 'REVOKE ' \
    | psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --echo-all
elif echo "$DB_RESTORE_FILE" | grep --quiet "\\.pgc$"; then
  pg_restore --no-password --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --jobs "$DB_RESTORE_NUMBER_OF_JOBS" --verbose --clean --if-exists --no-owner --no-acl "/backups/$DB_RESTORE_FILE"
else
  echo "Error: Unsupported file format. Use .sql.gz for plain format or .pgc for custom format"
  exit 1
fi

./fix-ownership.sh

echo "Database restore completed successfully"

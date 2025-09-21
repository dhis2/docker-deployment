#!/bin/sh

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

psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --command "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

if echo "$DB_RESTORE_FILE" | grep -q "\\.sql\\.gz$"; then
  gunzip --stdout "/backups/$DB_RESTORE_FILE" | psql --host "$POSTGRES_HOST" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --verbose
elif echo "$DB_RESTORE_FILE" | grep -q "\\.pgc$"; then
  pg_restore --no-password --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --jobs "$DB_RESTORE_NUMBER_OF_JOBS" --verbose --clean --if-exists "/backups/$DB_RESTORE_FILE"
else
  echo "Error: Unsupported file format. Use .sql.gz for plain format or .pgc for custom format"
  exit 1
fi

echo "Database restore completed successfully"

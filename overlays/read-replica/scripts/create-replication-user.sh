#!/usr/bin/env bash
set -e

echo "Waiting for database to be ready..."
until pg_isready --host "$POSTGRES_HOST"; do
  sleep 2
done

# Create the replication user (idempotent)
psql --host "$POSTGRES_HOST" -U postgres -v ON_ERROR_STOP=1 <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_REPLICATION_USERNAME}') THEN
    CREATE USER ${POSTGRES_REPLICATION_USERNAME} WITH REPLICATION LOGIN PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
    RAISE NOTICE 'Replication user created.';
  ELSE
    ALTER USER ${POSTGRES_REPLICATION_USERNAME} WITH PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
    RAISE NOTICE 'Replication user already exists. Password updated.';
  END IF;
END
\$\$;
EOF

# Add pg_hba.conf entry for replication if not already present
HBA_FILE="/var/lib/postgresql/data/pg_hba.conf"
HBA_ENTRY="host replication ${POSTGRES_REPLICATION_USERNAME} all scram-sha-256"

if ! grep -qF "$HBA_ENTRY" "$HBA_FILE"; then
  echo "$HBA_ENTRY" >> "$HBA_FILE"
  echo "Added replication entry to pg_hba.conf."

  # Reload PostgreSQL to pick up the pg_hba.conf change
  psql --host "$POSTGRES_HOST" -U postgres -c "SELECT pg_reload_conf();"
  echo "PostgreSQL configuration reloaded."
else
  echo "Replication entry already exists in pg_hba.conf."
fi

echo "Replication setup complete."

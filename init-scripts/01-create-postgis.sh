#!/usr/bin/env bash

# Create PostGIS extension in the dhis database using postgres superuser
PGPASSWORD="$POSTGRESQL_POSTGRES_PASSWORD" psql -v -U postgres -d "$POSTGRESQL_DATABASE" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

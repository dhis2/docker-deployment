#!/usr/bin/env bash
set -e

psql -v -U postgres -d "$POSTGRES_DB" -c "CREATE USER $POSTGRES_METRICS_USERNAME WITH PASSWORD '$POSTGRES_METRICS_PASSWORD';"
psql -v -U postgres -d "$POSTGRES_DB" -c "GRANT pg_monitor TO $POSTGRES_METRICS_USERNAME;"

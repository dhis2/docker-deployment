#!/usr/bin/env bash
set -e

psql -v -U $POSTGRES_USER -d $POSTGRES_DB -c "CREATE EXTENSION IF NOT EXISTS postgis;"

psql -v -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT PostGIS_Version();"

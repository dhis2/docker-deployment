#!/usr/bin/env bash

set -o errexit

exec_psql() {
  psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --tuples-only --no-align --quiet --command "$1"
}

change_owner() {
  local query="$1"
  local obj_type="$2"
  entities=$(exec_psql "$query")
  for entity in $entities; do
    # The below seems to fix: /restore-database.sh: 59: Syntax error: Unterminated quoted string
    entity=${entity//\"/\"\"}
    echo "Changing owner of $obj_type $entity to $POSTGRES_USER"
    exec_psql "ALTER $obj_type \"$entity\" OWNER TO $POSTGRES_USER"
  done
}

exec_psql "CREATE EXTENSION IF NOT EXISTS postgis"
exec_psql "CREATE EXTENSION IF NOT EXISTS pg_trgm"
exec_psql "CREATE EXTENSION IF NOT EXISTS btree_gin"

change_owner "SELECT tablename FROM pg_tables WHERE schemaname='public'" "TABLE"
change_owner "SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema='public'" "SEQUENCE"
change_owner "SELECT table_name FROM information_schema.views WHERE table_schema='public'" "VIEW"

exec_psql "ALTER DEFAULT PRIVILEGES FOR ROLE $POSTGRES_USER IN SCHEMA public GRANT ALL ON TABLES TO $POSTGRES_USER"
exec_psql "ALTER DEFAULT PRIVILEGES FOR ROLE $POSTGRES_USER IN SCHEMA public GRANT ALL ON SEQUENCES TO $POSTGRES_USER"
exec_psql "ALTER DEFAULT PRIVILEGES FOR ROLE $POSTGRES_USER IN SCHEMA public GRANT ALL ON FUNCTIONS TO $POSTGRES_USER"

#!/usr/bin/env bash
set -e

DATA_DIR="/var/lib/postgresql/data"

if [ "${FORCE_REINIT:-false}" = "true" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "FORCE_REINIT is set. Clearing existing replica data..."
    rm -rf "${DATA_DIR:?}"/*
fi

if [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "Data directory is empty. Initializing replica from primary..."

    pg_basebackup \
        -h database \
        -U "${POSTGRES_REPLICATION_USERNAME}" \
        -D "$DATA_DIR" \
        -Fp \
        -Xs \
        -P \
        -R

    echo "Replica initialization complete."
else
    echo "Data directory already initialized. Skipping pg_basebackup."

    # Ensure standby.signal exists in case of restart
    touch "$DATA_DIR/standby.signal"
fi

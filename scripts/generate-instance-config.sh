#!/usr/bin/env bash
set -euo pipefail

# Generate per-instance dhis2 and postgresql config by copying the shared
# defaults from config/ into instances/<PROJECT_NAME>/. The compose files mount
# these per-instance copies via ${COMPOSE_PROJECT_NAME}, so each instance can be
# tuned independently.

: "${GEN_PROJECT_NAME:?Environment variable GEN_PROJECT_NAME must be set}"

INSTANCE_DIR="instances/${GEN_PROJECT_NAME}"

if [ -e "${INSTANCE_DIR}/dhis2" ] || [ -e "${INSTANCE_DIR}/postgresql" ]; then
  echo "Error: config for instance '${GEN_PROJECT_NAME}' already exists in '${INSTANCE_DIR}'." >&2
  exit 1
fi

mkdir -p "${INSTANCE_DIR}"
cp -r config/dhis2 "${INSTANCE_DIR}/dhis2"
cp -r config/postgresql "${INSTANCE_DIR}/postgresql"

echo "A new config for instance '${GEN_PROJECT_NAME}' has been generated in '${INSTANCE_DIR}'!"

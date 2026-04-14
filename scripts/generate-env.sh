#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env-utils.sh
source "$SCRIPT_DIR/lib/env-utils.sh"

check_required_commands

MONITORING_ENV="stacks/monitoring/.env"
if [ ! -f "$MONITORING_ENV" ]; then
  echo "Error: '$MONITORING_ENV' not found." >&2
  echo "Run 'make generate-stack-envs' first to set up the shared stacks." >&2
  exit 1
fi

# If GEN_PROJECT_NAME is set, write to instances/<name>.env instead of .env.
if [ -n "${GEN_PROJECT_NAME:-}" ]; then
  mkdir -p instances
  OUTPUT_FILE="instances/${GEN_PROJECT_NAME}.env"
else
  OUTPUT_FILE=".env"
fi
TEMPLATE_FILE=".env.template"

if [ -f "$OUTPUT_FILE" ]; then
  echo "Error: '$OUTPUT_FILE' already exists." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template '$TEMPLATE_FILE' not found!" >&2
  exit 1
fi

# Validate required inputs
: "${GEN_APP_HOSTNAME:?Environment variable GEN_APP_HOSTNAME must be set}"

DHIS2_ADMIN_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB_PASSWORD=$(generate_password)
POSTGRES_METRICS_PASSWORD=$(generate_password)

# Read shared monitoring credentials from the monitoring stack env so all instances match.
DHIS2_MONITOR_PASSWORD=$(grep -E '^DHIS2_MONITOR_PASSWORD=' "$MONITORING_ENV" | cut -d= -f2-)
DHIS2_MONITOR_USERNAME=$(grep -E '^DHIS2_MONITOR_USERNAME=' "$MONITORING_ENV" | cut -d= -f2-)

cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Remove the first line beginning with "# NOTE!!!:" and any leading blank lines
sed "${SED_FLAGS[@]}" -e '/^# NOTE!!!:/d' -e '/./,$!d' "$OUTPUT_FILE"

update_env_var "$OUTPUT_FILE" "DHIS2_ADMIN_PASSWORD" "$DHIS2_ADMIN_PASSWORD"
update_env_var "$OUTPUT_FILE" "DHIS2_MONITOR_USERNAME" "$DHIS2_MONITOR_USERNAME"
update_env_var "$OUTPUT_FILE" "DHIS2_MONITOR_PASSWORD" "$DHIS2_MONITOR_PASSWORD"
update_env_var "$OUTPUT_FILE" "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
update_env_var "$OUTPUT_FILE" "POSTGRES_DB_PASSWORD" "$POSTGRES_DB_PASSWORD"
update_env_var "$OUTPUT_FILE" "POSTGRES_METRICS_PASSWORD" "$POSTGRES_METRICS_PASSWORD"
update_env_var "$OUTPUT_FILE" "APP_HOSTNAME" "$GEN_APP_HOSTNAME"

chmod u+rw,go-rwx "$OUTPUT_FILE"

echo "A new $OUTPUT_FILE has been generated!"

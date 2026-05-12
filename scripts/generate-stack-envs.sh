#!/usr/bin/env bash
set -euo pipefail

# Generates .env files for the standalone stacks (stacks/traefik/ and stacks/monitoring/).
# Run this once during initial server setup, before deploying any instances.
#
# Required environment variables:
#   GEN_LETSENCRYPT_ACME_EMAIL  - Email address for Let's Encrypt registration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/env-utils.sh
source "$SCRIPT_DIR/lib/env-utils.sh"

# shellcheck disable=SC2119
check_required_commands

TRAEFIK_ENV="stacks/traefik/.env"
MONITORING_ENV="stacks/monitoring/.env"

for f in "$TRAEFIK_ENV" "$MONITORING_ENV"; do
  if [ -f "$f" ]; then
    echo "Error: '$f' already exists. Remove it first if you want to regenerate." >&2
    exit 1
  fi
done

: "${GEN_LETSENCRYPT_ACME_EMAIL:?Environment variable GEN_LETSENCRYPT_ACME_EMAIL must be set}"

GRAFANA_ADMIN_PASSWORD=$(generate_password)
DHIS2_MONITOR_PASSWORD=$(generate_password)

cp stacks/traefik/.env.template "$TRAEFIK_ENV"
update_env_var "$TRAEFIK_ENV" "LETSENCRYPT_ACME_EMAIL" "$GEN_LETSENCRYPT_ACME_EMAIL"
chmod u+rw,go-rwx "$TRAEFIK_ENV"

cp stacks/monitoring/.env.template "$MONITORING_ENV"
update_env_var "$MONITORING_ENV" "GRAFANA_ADMIN_PASSWORD" "$GRAFANA_ADMIN_PASSWORD"
update_env_var "$MONITORING_ENV" "DHIS2_MONITOR_PASSWORD" "$DHIS2_MONITOR_PASSWORD"
chmod u+rw,go-rwx "$MONITORING_ENV"

echo "Generated $TRAEFIK_ENV"
echo "Generated $MONITORING_ENV"
echo ""
echo "Grafana will be available at: https://grafana.internal (via VPN)"
echo "Grafana admin password stored in: $MONITORING_ENV"

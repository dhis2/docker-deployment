#!/usr/bin/env bash

REQUIRED_COMMANDS=("tr" "head" "fold" "shuf" "sed" "chmod" "cp")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING_COMMANDS+=("$cmd")
  fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
  echo "Error: The following required commands are not available:" >&2
  printf "  - %s\n" "${MISSING_COMMANDS[@]}" >&2
  echo "" >&2
  echo "Please install the missing commands and try again." >&2
  exit 1
fi

OUTPUT_FILE=".env"
TEMPLATE_FILE=".env.template"

if [ -f "$OUTPUT_FILE" ]; then
  echo "Error: An '$OUTPUT_FILE' file already exists." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template '$TEMPLATE_FILE' not found!" >&2
  exit 1
fi

LENGTH=32
CHARSET='A-Za-z0-9_=.-'

generate_password() {
  local password=""
  password+=$(LC_ALL=C tr -dc '[:upper:]' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '[:lower:]' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '_=.-' < /dev/urandom | head -c 1)
  local remaining=$((LENGTH - 4))
  password+=$(LC_ALL=C tr -dc "$CHARSET" < /dev/urandom | head -c "$remaining")
  echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# Validate required inputs for ungeneratable values
: "${GEN_APP_HOSTNAME:?Environment variable GEN_APP_HOSTNAME must be set}"
: "${GEN_LETSENCRYPT_ACME_EMAIL:?Environment variable GEN_LETSENCRYPT_ACME_EMAIL must be set}"

DHIS2_ADMIN_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB_PASSWORD=$(generate_password)
POSTGRES_METRICS_PASSWORD=$(generate_password)
GRAFANA_ADMIN_PASSWORD=$(generate_password)
DHIS2_MONITOR_PASSWORD=$(generate_password)

# Detect GNU vs BSD sed
if sed --version >/dev/null 2>&1; then
  SED_FLAGS=(-i)
else
  SED_FLAGS=(-i '')
fi

cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Remove the first line beginning with "# NOTE!!!:" and any leading blank lines
sed "${SED_FLAGS[@]}" -e '/^# NOTE!!!:/d' -e '/./,$!d' "$OUTPUT_FILE"

update_env_var() {
  local key="$1"
  local value="$2"
  sed "${SED_FLAGS[@]}" "s|^${key}=.*|${key}=${value}|" "$OUTPUT_FILE"
}

update_env_var "DHIS2_ADMIN_PASSWORD" "$DHIS2_ADMIN_PASSWORD"
update_env_var "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
update_env_var "POSTGRES_DB_PASSWORD" "$POSTGRES_DB_PASSWORD"
update_env_var "POSTGRES_METRICS_PASSWORD" "$POSTGRES_METRICS_PASSWORD"
update_env_var "GRAFANA_ADMIN_PASSWORD" "$GRAFANA_ADMIN_PASSWORD"
update_env_var "DHIS2_MONITOR_PASSWORD" "$DHIS2_MONITOR_PASSWORD"
update_env_var "APP_HOSTNAME" "$GEN_APP_HOSTNAME"
update_env_var "LETSENCRYPT_ACME_EMAIL" "$GEN_LETSENCRYPT_ACME_EMAIL"

chmod u+rw,go-rwx "$OUTPUT_FILE"

echo "A new $OUTPUT_FILE has been generated!"

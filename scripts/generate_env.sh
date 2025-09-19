#!/usr/bin/env bash

LENGTH=32
CHARSET='A-Za-z0-9_=.-'
OUTPUT_FILE=".env"
TEMPLATE_FILE=".env.example"

generate_password() {
    local password=""
    password+=$(LC_ALL=C tr -dc 'A-Z' < /dev/urandom | head -c 1)
    password+=$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 1)
    password+=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 1)
    password+=$(LC_ALL=C tr -dc '_=.-' < /dev/urandom | head -c 1)
    local remaining=$((LENGTH - 4))
    password+=$(LC_ALL=C tr -dc "$CHARSET" < /dev/urandom | head -c "$remaining")
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

if [ -f "$OUTPUT_FILE" ]; then
  echo "Error: An '$OUTPUT_FILE' file already exists." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template '$TEMPLATE_FILE' not found!" >&2
  exit 1
fi

DHIS2_ADMIN_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB_PASSWORD=$(generate_password)
GRAFANA_ADMIN_PASSWORD=$(generate_password)
DHIS2_MONITOR_PASSWORD=$(generate_password)

cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Detect GNU vs BSD sed
if sed --version >/dev/null 2>&1; then
  SED_FLAGS="-i"
else
  SED_FLAGS="-i ''"
fi

sed "$SED_FLAGS" "s/^DHIS2_ADMIN_PASSWORD=.*/DHIS2_ADMIN_PASSWORD=$DHIS2_ADMIN_PASSWORD/" "$OUTPUT_FILE"
sed "$SED_FLAGS" "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" "$OUTPUT_FILE"
sed "$SED_FLAGS" "s/^POSTGRES_DB_PASSWORD=.*/POSTGRES_DB_PASSWORD=$POSTGRES_DB_PASSWORD/" "$OUTPUT_FILE"
sed "$SED_FLAGS" "s/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD/" "$OUTPUT_FILE"
sed "$SED_FLAGS" "s/^DHIS2_MONITOR_PASSWORD=.*/DHIS2_MONITOR_PASSWORD=$DHIS2_MONITOR_PASSWORD/" "$OUTPUT_FILE"

chmod u+rw,go-rwx "$OUTPUT_FILE"

echo "A new $OUTPUT_FILE has been generated!"

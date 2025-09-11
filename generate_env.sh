#!/usr/bin/env bash

LENGTH=32
CHARSET='A-Za-z0-9_=.-'
OUTPUT_FILE=".env"
TEMPLATE_FILE=".env.example"

if [ -f "$OUTPUT_FILE" ]; then
  echo "Error: An '$OUTPUT_FILE' file already exists." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template '$TEMPLATE_FILE' not found!" >&2
  exit 1
fi

POSTGRESQL_PASSWORD=$(LC_ALL=C tr -dc "$CHARSET" < /dev/urandom | head -c "$LENGTH")
POSTGRESQL_POSTGRES_PASSWORD=$(LC_ALL=C tr -dc "$CHARSET" < /dev/urandom | head -c "$LENGTH")

cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Detect GNU vs BSD sed
if sed --version >/dev/null 2>&1; then
  # GNU sed
  sed -i "s/^POSTGRESQL_PASSWORD=.*/POSTGRESQL_PASSWORD=$POSTGRESQL_PASSWORD/" "$OUTPUT_FILE"
  sed -i "s/^POSTGRESQL_POSTGRES_PASSWORD=.*/POSTGRESQL_POSTGRES_PASSWORD=$POSTGRESQL_POSTGRES_PASSWORD/" "$OUTPUT_FILE"
else
  # BSD sed (macOS)
  sed -i '' "s/^POSTGRESQL_PASSWORD=.*/POSTGRESQL_PASSWORD=$POSTGRESQL_PASSWORD/" "$OUTPUT_FILE"
  sed -i '' "s/^POSTGRESQL_POSTGRES_PASSWORD=.*/POSTGRESQL_POSTGRES_PASSWORD=$POSTGRESQL_POSTGRES_PASSWORD/" "$OUTPUT_FILE"
fi

chmod u+rw,go-rwx "$OUTPUT_FILE"

echo "A new $OUTPUT_FILE has been generated!"
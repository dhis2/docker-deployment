#!/usr/bin/env bash

set -euo pipefail

# Collect all services that define a healthcheck
SERVICES=$(
  docker compose -f docker-compose.yml \
                 -f overlays/docker-compose.traefik-dashboard.yml \
                 -f overlays/docker-compose.monitoring.yml \
    config \
  | yq -o=json \
  | jq -r '.services | to_entries[] | select(.value.healthcheck) | .key'
)

echo "Services with health checks: $SERVICES"
echo "Waiting for services with health checks to be healthy..."

while true; do
  all_healthy=true

  for service in $SERVICES; do
    name=$(docker compose ps --format "table {{.Name}}\t{{.Service}}" \
             | awk -v s="$service" '$2 == s {print $1}')

    if [ -z "$name" ]; then
      echo "Service $service not running, skipping..."
      continue
    fi

    echo -n "Checking $name... "
    status=$(docker inspect "$name" --format "{{.State.Health.Status}}")

    if [ "$status" = "healthy" ]; then
      echo "✅ healthy"
    else
      echo "❌ $status"
      all_healthy=false
      break
    fi
  done

  if $all_healthy; then
    echo "All services with health checks are healthy."
    break
  fi

  sleep 5
done

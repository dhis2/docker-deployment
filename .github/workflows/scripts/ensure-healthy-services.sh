#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME must be set}"

echo "Waiting for services in project '$PROJECT_NAME' with health checks to be healthy..."

while true; do
  all_healthy=true

  mapfile -t CONTAINERS < <(
    docker ps \
      --filter "label=com.docker.compose.project=$PROJECT_NAME" \
      --format '{{.Names}}'
  )

  if [ "${#CONTAINERS[@]}" -eq 0 ]; then
    echo "No containers running yet for project '$PROJECT_NAME'..."
    sleep 5
    continue
  fi

  for name in "${CONTAINERS[@]}"; do
    status=$(docker inspect "$name" \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}')

    case "$status" in
      none)
        ;;
      healthy)
        echo "✅ $name healthy"
        ;;
      *)
        echo "❌ $name $status"
        all_healthy=false
        break
        ;;
    esac
  done

  if $all_healthy; then
    echo "All services with health checks are healthy."
    break
  fi

  sleep 5
done

#!/bin/sh

set -o errexit
set -o nounset

apk add --no-cache curl jq

echo "Creating monitoring role..."
echo "Hostname: $DHIS2_HOSTNAME; Username: $DHIS2_ADMIN_USERNAME"
set +o errexit # Disable exit on error so we can actually capture any potential curl errors and show them
ROLE_RESPONSE=$(curl -s -X POST "$DHIS2_HOSTNAME/api/userRoles" \
  -H "Content-Type: application/json" \
  -d '{"name":"monitoring","authorities":["M_dhis-web-dashboard"]}' \
  --basic --user "$DHIS2_ADMIN_USERNAME:$DHIS2_ADMIN_PASSWORD" \
  -w "\n%{http_code}")
CURL_EXIT=$?
set -o errexit

if [ $CURL_EXIT -ne 0 ]; then
  echo "Curl failed for role creation with exit code $CURL_EXIT. Response: $ROLE_RESPONSE"
  exit 1
fi

ROLE_STATUS=$(echo "$ROLE_RESPONSE" | tail -n1)
ROLE_JSON=$(echo "$ROLE_RESPONSE" | head -n -1)

if [ "$ROLE_STATUS" -ne 201 ]; then
  if [ "$ROLE_STATUS" -eq 409 ]; then
    echo "Role already exists: Status: $ROLE_STATUS. Response: $ROLE_JSON"
    exit 0
  fi
  echo "Failed to create role. Status: $ROLE_STATUS. Response: $ROLE_JSON"
  exit 1
fi

ROLE_ID=$(echo "$ROLE_JSON" | jq -r ".response.uid")
if [ "$ROLE_ID" = "null" ] || [ -z "$ROLE_ID" ]; then
  echo "Failed to extract role ID from response: $ROLE_JSON"
  exit 1
fi

echo "Created role with id: $ROLE_ID"

echo "Creating monitoring user..."
set +o errexit
USER_RESPONSE=$(curl -s -X POST "$DHIS2_HOSTNAME/api/users" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{
        \"username\": \"$DHIS2_MONITOR_USERNAME\",
        \"password\": \"$DHIS2_MONITOR_PASSWORD\",
        \"userRoles\": [
          { \"id\": \"$ROLE_ID\" }
        ],
        \"firstName\": \"moni\",
        \"surname\": \"tor\"
      }" \
  --basic --user "$DHIS2_ADMIN_USERNAME:$DHIS2_ADMIN_PASSWORD" \
  -w "\n%{http_code}")
CURL_EXIT=$?
set -o errexit

if [ $CURL_EXIT -ne 0 ]; then
  echo "Curl failed for user creation with exit code $CURL_EXIT"
  exit 1
fi

USER_STATUS=$(echo "$USER_RESPONSE" | tail -n1)
USER_JSON=$(echo "$USER_RESPONSE" | head -n -1)

if [ "$USER_STATUS" -ne 201 ]; then
  if [ "$USER_STATUS" -eq 409 ]; then
    echo "User already exists: Status: $USER_STATUS. Response: $USER_JSON"
    exit 0
  fi
  echo "Failed to create user. Status: $USER_STATUS. Response: $USER_JSON"
  exit 1
fi

USER_ID=$(echo "$USER_JSON" | jq -r ".response.uid")
if [ "$USER_ID" = "null" ] || [ -z "$USER_ID" ]; then
  echo "Failed to extract user ID from response: $USER_JSON"
  exit 1
fi

echo "Created user with id: $USER_ID"

#!/bin/sh

set -o errexit
set -o nounset

URL="https://github.com/shoenig/bcrypt-tool/releases/download/v1.1.7/bcrypt-tool_1.1.7_linux_amd64.tar.gz"
EXPECTED_SHA="7eb3f0cc159a54e4a1efb0fc56c11a5eb80efa5c88b482d0034eceea4cdf936e"

curl --location --output bcrypt-tool.tar.gz "$URL"

echo "${EXPECTED_SHA}  bcrypt-tool.tar.gz" | sha256sum --check

tar --extract --gzip --file bcrypt-tool.tar.gz --no-same-owner

HASH=$(./bcrypt-tool hash "$DHIS2_ADMIN_PASSWORD")

export PGPASSWORD="$POSTGRES_PASSWORD"
psql --host "$POSTGRES_HOST" --username postgres --dbname "$POSTGRES_DB" --command "UPDATE \"userinfo\" SET \"password\" = '$HASH' WHERE \"username\" = '$DHIS2_ADMIN_USERNAME';"

rm bcrypt-tool.tar.gz bcrypt-tool

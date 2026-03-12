#!/usr/bin/env sh

set -eu

mkdir -p /cert
touch /cert/acme.json
chown nobody:nobody /cert/acme.json
chmod 600 /cert/acme.json

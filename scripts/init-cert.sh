#!/usr/bin/env sh

set -eu

touch /cert/acme.json
chown nobody:nobody /cert/acme.json
chmod 600 /cert/acme.json

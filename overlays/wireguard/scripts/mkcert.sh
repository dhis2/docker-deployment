#!/bin/sh

set -eu

mkcert -install

if [ ! -f "/certs/internal.crt" ] || [ ! -f "/certs/internal.key" ]; then
    mkcert -cert-file "/certs/internal.crt" -key-file "/certs/internal.key" \
        grafana.internal "*.glowroot.internal"
    chown nobody:nobody "/certs/internal.key"
    chmod 640 "/certs/internal.key"
fi

# Export the root CA to the shared volume so clients can fetch and trust it.
# Only present in CAROOT on first-time generation; on subsequent starts the
# skip above leaves CAROOT empty and rootCA.pem is already in /certs.
CAROOT_FILE="$(mkcert -CAROOT)/rootCA.pem"
if [ -f "$CAROOT_FILE" ]; then
    cp "$CAROOT_FILE" /certs/rootCA.pem
    chmod 644 /certs/rootCA.pem
fi

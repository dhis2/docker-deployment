#!/bin/sh

set -eu

if [ ! -f "/certs/internal.crt" ] || [ ! -f "/certs/internal.key" ]; then
    mkcert -install
    mkcert 'grafana.internal' 'glowroot.internal'
    mv grafana.internal+1.pem /certs/internal.crt
    mv grafana.internal+1-key.pem /certs/internal.key
    chmod 644 /certs/internal.key
fi

# Export the root CA to the shared volume so clients can fetch and trust it.
# Only present in CAROOT on first-time generation; on subsequent starts the
# skip above leaves CAROOT empty and rootCA.pem is already in /certs.
CAROOT_FILE="$(mkcert -CAROOT)/rootCA.pem"
if [ -f "$CAROOT_FILE" ]; then
    cp "$CAROOT_FILE" /certs/rootCA.pem
    chmod 644 /certs/rootCA.pem
fi

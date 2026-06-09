#!/bin/sh

set -eu

mkcert -install

for host in grafana.internal glowroot.internal; do
    if [ ! -f "/certs/${host}.crt" ] || [ ! -f "/certs/${host}.key" ]; then
        mkcert "${host}"
        mv "${host}.pem" "/certs/${host}.crt"
        mv "${host}-key.pem" "/certs/${host}.key"
        chmod 600 "/certs/${host}.key"
    fi
done

# Export the root CA to the shared volume so clients can fetch and trust it.
# Only present in CAROOT on first-time generation; on subsequent starts the
# skip above leaves CAROOT empty and rootCA.pem is already in /certs.
CAROOT_FILE="$(mkcert -CAROOT)/rootCA.pem"
if [ -f "$CAROOT_FILE" ]; then
    cp "$CAROOT_FILE" /certs/rootCA.pem
    chmod 644 /certs/rootCA.pem
fi

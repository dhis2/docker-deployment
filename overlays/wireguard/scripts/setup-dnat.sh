#!/bin/sh
set -e

TRAEFIK_IP=$(getent hosts traefik | awk '{print $1}')

if [ -z "$TRAEFIK_IP" ]; then
    echo "setup-dnat: could not resolve traefik, skipping DNAT rules"
    exit 0
fi

echo "setup-dnat: adding DNAT rules for traefik at ${TRAEFIK_IP}"
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 80  -j DNAT --to-destination "${TRAEFIK_IP}:80"
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 443 -j DNAT --to-destination "${TRAEFIK_IP}:443"

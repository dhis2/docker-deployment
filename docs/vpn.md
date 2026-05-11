# VPN access via WireGuard

The `overlays/wireguard` overlay brings up a WireGuard VPN endpoint and a wildcard
certificate issuer so that authorized clients can reach admin/monitoring UIs
over a private tunnel using `*.internal` hostnames:

| Hostname            | Service                |
| ------------------- | ---------------------- |
| `grafana.internal`  | Grafana (monitoring)   |
| `glowroot.internal` | Glowroot APM UI        |

The main DHIS2 application continues to be served publicly on `${APP_HOSTNAME}`
via Let's Encrypt — it is not re-exposed over the VPN.

## How it works

- **WireGuard** (`linuxserver/wireguard`) listens on UDP/`${WIREGUARD_SERVER_PORT}` and generates per-peer configs under `overlays/wireguard/config/`.
- **CoreDNS** is the resolver bundled inside the WireGuard container. The file `overlays/wireguard/coredns/Corefile` is bind-mounted over its config and defines an
  `internal` zone that CNAMEs every `*.internal` name to the Docker service name `traefik`. Docker's embedded DNS resolves that to the Traefik container's IP on the `frontend` network.
- **Traefik** gets two additions from the overlay:
  - A new TLS store `internal` whose default certificate is the wildcard
    `*.internal` issued by the `mkcert` sidecar.
  - Dynamic routers (`grafana-internal`, `glowroot-internal`) loaded from
    `overlays/wireguard/traefik/internal.yml`. The overlay switches Traefik from a single-file provider to a directory provider so both the baseline
    `traefik/dynamic.yml` and the internal routes are served at once.
- Clients connected to the VPN use the server's CoreDNS (`PEERDNS=auto`) and route `${WIREGUARD_ALLOWED_IPS}` through the tunnel (default `0.0.0.0/0` = full tunnel; narrow this for split tunnelling).

## Configuration

Set these in your `.env` (all have defaults — see `.env.template`):

| Variable                     | Default     | Description                                     |
| ---------------------------- |-------------| ----------------------------------------------- |
| `WIREGUARD_PEERS`            | `dhis2`     | Comma-separated peer names to generate configs for |
| `WIREGUARD_SERVER_URL`       | `auto`      | Public endpoint clients will connect to         |
| `WIREGUARD_SERVER_PORT`      | `51820`     | UDP port WireGuard listens on                   |
| `WIREGUARD_INTERNAL_SUBNET`  | `10.8.0.0`  | Tunnel subnet (avoid overlap with local networks) |
| `WIREGUARD_ALLOWED_IPS`      | `0.0.0.0/0` | CIDRs routed through the tunnel on the client (full vs. split tunnel) |

## Launch

```shell
make launch-vpn
```

This runs the same stack as `make launch` plus the VPN overlay. Use
`make clean-vpn` to stop it.

> **Firewall:** open UDP/`${WIREGUARD_SERVER_PORT}` inbound on the host. Updating
> `server-tools/roles/harden/` to open this port automatically is tracked as
> separate work.

## Enrol a peer

Export the peer's config:

```shell
docker compose -f docker-compose.yml \
    -f overlays/traefik-dashboard/docker-compose.yml \
    -f overlays/monitoring/docker-compose.yml \
    -f overlays/profiling/docker-compose.yml \
    -f overlays/glowroot/docker-compose.yml \
    -f overlays/wireguard/docker-compose.yml \
    exec wireguard cat /config/peer_laptop/peer_dhis2.conf > peer.conf
```

Adjust the `Endpoint` port in the generated config if you changed
`WIREGUARD_SERVER_PORT`, then import it into your client. On Linux with
NetworkManager:

```shell
nmcli connection import type wireguard file ./peer.conf
```

QR codes for mobile clients are written alongside each peer's config
(`peer_<name>.png`).

## Trust the internal CA

The `mkcert` sidecar creates a short-lived internal CA the first time the
overlay starts. Copy the root certificate out and install it on the client:

```shell
docker compose -f docker-compose.yml -f overlays/wireguard/docker-compose.yml \
    cp mkcert:/root/.local/share/mkcert/rootCA.pem .
```

Install it in your OS trust store (macOS Keychain, or `/usr/local/share/ca-certificates/` plus `update-ca-certificates` on Linux) so browsers accept `https://*.internal` without warnings.

## Verify

With the VPN connected and the root CA trusted:

```shell
dig grafana.internal
curl -v https://grafana.internal
curl -v https://glowroot.internal
```

The public hostname should continue to work unchanged:

```shell
curl -v https://${APP_HOSTNAME}
```

# VPN access via WireGuard

The standalone WireGuard stack provides a private tunnel for reaching admin and
monitoring UIs that are not exposed publicly:

| Hostname            | Service              |
| ------------------- | -------------------- |
| `grafana.internal`  | Grafana (monitoring) |
| `glowroot.internal` | Glowroot APM UI      |

DHIS2 itself stays public on `${APP_HOSTNAME}` via Let's Encrypt — only admin
surfaces are moved behind the VPN.

## How it works

```text
Client                          Server
┌──────────┐                    ┌───────────────────────────────────────────┐
│ Browser  │                    │  wireguard container                      │
│          │                    │  ┌─────────────────────────────────────┐  │
│  ↓ DNS   │   WireGuard UDP    │  │ wg0 (10.8.0.1)                      │  │
│ 10.8.0.1 │ ◀───── tunnel ───▶ │  │ CoreDNS  → *.internal → 10.8.0.1    │  │
│          │                    │  │ socat    → :443 → traefik:443       │  │
│  ↓ TCP   │                    │  └─────────────────────────────────────┘  │
│ :443     │                    │             │                             │
└──────────┘                    │             ▼  (proxy network)            │
                                │  ┌─────────────────────────────────────┐  │
                                │  │ traefik                             │  │
                                │  │  internal.yml → grafana, glowroot   │  │
                                │  │  TLS: wireguard-certs volume        │  │
                                │  └─────────────────────────────────────┘  │
                                └───────────────────────────────────────────┘
```

- **WireGuard** (`linuxserver/wireguard`) terminates the VPN tunnel and generates per-peer client configs under `overlays/wireguard/config/`.
- **CoreDNS** (bundled in the WireGuard container, configured via
  `overlays/wireguard/coredns/Corefile`) answers `*.internal` with `10.8.0.1` for VPN clients.
- **socat sidecar** (`wireguard-proxy`) runs in the WireGuard container's network namespace and forwards `10.8.0.1:443` to `traefik:443` over the
  `proxy` Docker network. Docker DNS resolves `traefik` on each new connection, so Traefik container restarts don't require any reconfiguration.
- **mkcert** runs once on first launch to create a self-signed root CA and certs for `grafana.internal` / `glowroot.internal`, stored in the
  `wireguard-certs` Docker volume.
- **Traefik** mounts the same `wireguard-certs` volume read-only at
  `/etc/traefik/certs/` and serves the internal routes defined in
  `stacks/traefik/conf.d/internal.yml`. Internal routes use the
  `security-internal` middleware (everything `security` has except HSTS) — HSTS on a self-signed cert would lock browsers out unrecoverably if a client hit the route before trusting the CA.

## Configuration

Set these as environment variables when running `make start-vpn` (all have
defaults):

| Variable                    | Default     | Description                                                            |
| --------------------------- | ----------- | ---------------------------------------------------------------------- |
| `WIREGUARD_PEERS`           | `laptop`    | Comma-separated peer names to generate configs for                     |
| `WIREGUARD_SERVER_URL`      | `auto`      | Public endpoint clients connect to (use the server's public IP or FQDN) |
| `WIREGUARD_SERVER_PORT`     | `51820`     | UDP port WireGuard listens on                                          |
| `WIREGUARD_INTERNAL_SUBNET` | `10.8.0.0`  | Tunnel subnet (must not overlap with the client's local networks)      |
| `WIREGUARD_ALLOWED_IPS`     | `0.0.0.0/0` | CIDRs routed through the tunnel on the client (full vs. split tunnel)  |

## Launch

```shell
WIREGUARD_SERVER_URL=<server-public-ip-or-fqdn> \
WIREGUARD_PEERS=alice,bob \
  make start-vpn
```

This brings up `mkcert` (one-shot — generates certs on first run, no-op
afterwards), then `wireguard`, then `wireguard-proxy`, and finally touches
`stacks/traefik/conf.d/internal.yml` so the running Traefik reloads and picks
up the newly minted certs.

Use `make stop-vpn` to tear down the stack. Peer configs and the cert volume
persist across restarts.

> **Firewall:** UDP `${WIREGUARD_SERVER_PORT}` must be open inbound on the
> server. The `server-tools/` Ansible role configures this when its
> `wireguard_server_port` matches the value used here.

## Enrol a peer

After `make start-vpn`, each peer's config lives at
`overlays/wireguard/config/peer_<name>/peer_<name>.conf` (root-owned because
the container ran as root). Extract one with:

```shell
sudo cat overlays/wireguard/config/peer_alice/peer_alice.conf > alice.conf
```

For mobile clients, QR codes are written alongside as `peer_<name>.png`.

Import on Linux with NetworkManager:

```shell
nmcli connection import type wireguard file ./alice.conf
# Route .internal queries to the VPN's CoreDNS instead of the system resolver
nmcli connection modify alice ipv4.dns-search "~internal"
nmcli connection up alice
```

The `~internal` search domain is important: it tells systemd-resolved to send
`.internal` queries to the WireGuard DNS (10.8.0.1) rather than the system's
default resolver, which would otherwise return NXDOMAIN.

## Trust the internal CA

The mkcert root CA is self-signed and unique per server. Without installing
it, browsers reject `https://grafana.internal` with an untrusted-cert warning.
Export it from the `wireguard-certs` volume:

```shell
make get-vpn-ca
```

This writes `rootCA.pem` to the current directory. Install it in the OS trust
store:

- **Linux (Fedora/RHEL):** `sudo cp rootCA.pem /etc/pki/ca-trust/source/anchors/dhis2-mkcert.crt && sudo update-ca-trust`
- **Linux (Debian/Ubuntu):** `sudo cp rootCA.pem /usr/local/share/ca-certificates/dhis2-mkcert.crt && sudo update-ca-certificates`
- **macOS:** `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem`

Restart the browser (full quit) after installing.

> **Note:** Firefox uses its own trust store. Install via
> *Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import*.

## Verify

With the VPN connected and the CA installed:

```shell
resolvectl query grafana.internal     # should resolve to 10.8.0.1 via the VPN link
curl https://grafana.internal/api/health
```

The public DHIS2 hostname should continue to work whether or not the VPN is up:

```shell
curl https://${APP_HOSTNAME}/
```

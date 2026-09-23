# TLS certificates

How HTTPS certificates are obtained for public hostnames, and what happens when they cannot be.

Traefik terminates TLS for everything. HTTP on port 80 is redirected to HTTPS on 443, so there is no unencrypted path to an instance.

## Public hostnames — Let's Encrypt

Each instance's route requests a certificate from Let's Encrypt for its `APP_HOSTNAME`, using the TLS-ALPN-01 challenge on port 443. It happens automatically on first request, and renewal is automatic too. Issued certificates are stored in Traefik's `cert` volume, in `acme.json`, which survives `clean-traefik` — so restarting Traefik does not re-issue anything.

For this to work:

- The hostname must resolve **publicly** to the server's IP address.
- Port 443 must be reachable from the internet.
- `LETSENCRYPT_ACME_EMAIL` must be set, which `make generate-stack-envs` does from `GEN_LETSENCRYPT_ACME_EMAIL`.

### Use the staging CA first

Let's Encrypt's production rate limits are strict, and a handful of failed attempts — the wrong DNS record, a closed firewall port — can lock you out of issuing certificates for that name for days. The staging CA has much higher limits and is otherwise identical; its certificates are untrusted, so browsers warn and the issuer reads *Let's Encrypt (STAGING)*.

Set it in `stacks/traefik/.env`:

```dotenv
LETSENCRYPT_ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory
```

Validate the whole deployment there first. Then switch back and restart Traefik to get trusted certificates:

```dotenv
LETSENCRYPT_ACME_CASERVER=https://acme-v02.api.letsencrypt.org/directory
```

```shell
COMPOSE_OPTS=-d make start-traefik
```

| CA                   | Trusted by browsers | Rate limits | Use for                            |
|:--|:--|:--|:--|
| Production (default) | Yes                 | Strict      | Anything real                      |
| Staging              | No                  | Generous    | First setup, CI, repeated testing  |

Switching between the two leaves stale certificates in `acme.json`. If a browser keeps showing the old issuer after you switch, stop Traefik and remove its `cert` volume so it starts from nothing.

## Local hostnames — self-signed

On a laptop, Let's Encrypt cannot issue anything: it has to reach the name being validated, and names like `dhis2.127-0-0-1.nip.io` point at your own machine. Traefik falls back to its own self-signed certificate, which browsers warn about. Click through the warning; `curl` needs `-k`.

This is expected in the [demo](../guides/demo-environment.md) and [test](../guides/test-environment.md) guides. The email address you pass to `generate-stack-envs` is never used in that case, though it still has to be set.

To get a *trusted* certificate on a real server without DNS, use a nip.io name derived from the server's **public** IP — `dhis2.203-0-113-10.nip.io` for a server at `203.0.113.10`. That resolves publicly, so Let's Encrypt can validate it.

## Internal hostnames — a private authority

`grafana.internal` and `<name>.glowroot.internal` are not public names and cannot use Let's Encrypt. On the VPN's first start, `mkcert` generates a root certificate authority unique to that server plus certificates for the internal names, stored in the `wireguard-certs` volume. Traefik mounts that volume read-only and serves the internal routes from it.

Clients must install the root authority to avoid warnings:

```shell
make get-vpn-ca     # writes rootCA.pem
```

Per-platform installation instructions are in [VPN access](vpn.md).

Internal routes deliberately use the `security-internal` middleware, which applies the same security headers as public routes **except HSTS**. HSTS on a self-signed certificate would lock a browser out of the hostname unrecoverably if it hit the route before trusting the authority.

## Security headers

Public routes carry a `security` middleware defined in `stacks/traefik/conf.d/middlewares.yml`: HSTS for two years including subdomains and with preload, `frameDeny`, `contentTypeNosniff`, XSS filtering, and `strict-origin-when-cross-origin` as the referrer policy.

> [!NOTE]
> HSTS with `includeSubdomains` and `preload` tells browsers to refuse plain HTTP for your domain **and all of its subdomains** for two years. That is the right default for a dedicated DHIS2 domain, but if the parent domain serves anything over HTTP, reconsider it before going live — it is not something you can quickly undo on clients that have already seen the header.

## See also

- [VPN access](vpn.md) — the internal authority and its client setup.
- [Architecture](architecture.md) — the request path.
- [Troubleshooting](troubleshooting.md) — certificates that never appear.

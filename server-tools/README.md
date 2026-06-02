# DHIS2 Hosting Platform - Ansible

This Ansible playbook provisions a server and brings up the **shared hosting
stacks** for DHIS2: the Traefik gateway, the monitoring stack, and (optionally)
the WireGuard VPN.

It does **not** deploy DHIS2 instances. Instances are created and managed
separately with the `make` workflow in the repository root (`make
create-instance`, `make start-instance`, etc.).

## What it does

- **bootstrap**: installs Docker + Compose and required packages, creates the Docker user, and prepares the deploy directory.
- **firewall**: configures a default-deny `DOCKER-USER` firewall, allowing only SSH/HTTP/HTTPS (and the WireGuard port when the VPN is enabled).
- **harden**: SSH, kernel and Docker hardening (user-namespace remapping, etc.).
- **platform**: clones the repo, generates the shared stack env files, ensures the shared Docker networks exist, installs the Loki log driver, and runs the Traefik, monitoring and (optional) WireGuard stacks as **systemd services** (`traefik.service`, `monitoring.service`, `wireguard.service`).

Grafana is reachable only over the WireGuard VPN at `https://grafana.internal`.
With `enable_vpn: false` it is not reachable until a VPN is added.

## Configuration

Two files are **implementation-specific and gitignored** (they must not be
committed): `inventory.ini` (your hosts) and `group_vars/all.yml` (your
overrides). Create both before running.

### Inventory

Create `inventory.ini` describing your target host(s):

```ini
[servers]
my-server ansible_host=server.example.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_my_server
```

### Variables

Defaults for every variable live in each role's `defaults/main.yml`. Per
deployment, override only what you need in **`group_vars/all.yml`**.

Create `group_vars/all.yml` with at least the required variable:

```yaml
# Let's Encrypt ACME email (REQUIRED - no default)
letsencrypt_email: "{{ lookup('env', 'GEN_LETSENCRYPT_ACME_EMAIL') | mandatory }}"

# Optional overrides (showing defaults):
# enable_platform: true        # master switch for the platform role
# enable_vpn: true             # deploy WireGuard + open its UDP port
# repo_url: https://github.com/dhis2/docker-deployment
# repo_branch: master
# deploy_dir: /opt/dhis2
# docker_user: dhis2
# docker_group: docker
# allowed_ssh_users: [ ubuntu ]
# firewall_allowed_ports: [ 22, 80, 443 ]
# firewall_allowed_udp_ports: []   # WireGuard port is handled by enable_vpn
```

### Overridable variables

| Variable | Default | Role | Purpose |
| --- | --- | --- | --- |
| `letsencrypt_email` | _(none, required)_ | platform | ACME registration email for Traefik |
| `enable_platform` | `true` | platform | Run the platform role after provisioning server |
| `enable_vpn` | `true` | platform | Deploy WireGuard and open its UDP port |
| `repo_url` | `https://github.com/dhis2/docker-deployment` | platform | Repo to deploy from |
| `repo_branch` | `master` | platform | Branch to deploy |
| `deploy_dir` | `/opt/dhis2` | bootstrap | Checkout location on the host |
| `docker_user` / `docker_group` | `dhis2` / `docker` | bootstrap | Owner of the deploy dir |
| `allowed_ssh_users` | `[ ubuntu ]` | harden | SSH `AllowUsers` |
| `firewall_allowed_ports` | `[ 22, 80, 443 ]` | firewall | Host-facing TCP ports |
| `firewall_allowed_udp_ports` | `[]` | firewall | Extra UDP ports (WireGuard handled via `enable_vpn`) |
| `wireguard_port` | `51820` | firewall | WireGuard UDP port (opened when `enable_vpn`) |

## Usage

1. Set the Let's Encrypt email in your environment:

    ```bash
    export GEN_LETSENCRYPT_ACME_EMAIL=your.email@example.com
    ```

2. Create `inventory.ini` and `group_vars/all.yml` for your deployment (see above).

3. Copy your public SSH key to the target server:

    ```bash
    ssh-copy-id ubuntu@<your server ip>
    ```

4. Store your sudo password in `./.ansible_become_pass` (gitignored).

5. Run the playbook:

    ```bash
    make deployment
    ```

## After deployment

- The stacks run as systemd services: `systemctl status traefik monitoring wireguard`.
- To reach Grafana, connect to the VPN and export the root CA so your browser trusts the `*.internal` certificate (from the repo root):

    ```bash
    make get-vpn-ca   # writes rootCA.pem; install it in your OS/browser trust store
    ```

## Security notes

- Docker uses user-namespace remapping for least privilege.
- The firewall is default-deny; only SSH/HTTP/HTTPS (and WireGuard when enabled) are allowed, plus inter-container traffic on default Docker subnets.
- AppArmor and unattended-upgrades are enabled.
- Stack env files contain secrets and are generated on the host (gitignored in the deployed checkout).

> **Important:** Do **not** use UFW or other firewall frontends alongside this
> setup. Docker bypasses standard host chains, so UFW rules are ignored or may
> conflict. All host and container traffic is managed through the `firewall` role.
> See [roles/firewall/tasks/main.yml](roles/firewall/tasks/main.yml).

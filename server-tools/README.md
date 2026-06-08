# DHIS2 Server Provisioning - Ansible

This Ansible playbook **provisions and hardens a server** for running the DHIS2
Docker stacks, and optionally **checks out this repository** to the deploy
directory so an operator can run the `make` workflow on the box.

It does **not** start any containers. Starting and managing the stacks (Traefik,
monitoring, WireGuard VPN) and DHIS2 instances is done by an operator with the
`make` workflow in the repository root (`make start-traefik`, `make
start-monitoring`, `make start-vpn`, `make start-instance`, ...).

## What it does

- **bootstrap**: installs Docker + Compose and required packages (incl. `make`), optionally creates the operator user, and prepares the deploy directory.
- **firewall**: configures a default-deny `DOCKER-USER` firewall, allowing only SSH/HTTP/HTTPS, the WireGuard UDP port, and inter-container traffic.
- **harden**: SSH, kernel and Docker hardening (user-namespace remapping, etc.).
- **repo** (optional, `clone_repo`): clones/updates this repository into
  `deploy_dir`, owned by the operator user.

## The operator user and `sudo docker`

One user owns `deploy_dir`, runs `make`, and is the Docker user-namespace remap
target. By default this is the inventory `ansible_user` (no extra account is
created). To use a dedicated account, set `operator_user` (see below).

Operators are intentionally **not** added to the root-equivalent `docker` group.
Instead the `make` workflow runs docker via `sudo` by default (explicit and
logged). That's controlled by the `SUDO` variable in the root `Makefile`:

```bash
make start-traefik              # runs: sudo docker compose ...
make start-traefik SUDO=        # no sudo (e.g. dev container, or user in docker group)
```

So `make` will prompt for the operator's sudo password when starting containers.

## Configuration

Two files are **implementation-specific and gitignored** (must not be committed):
`inventory.ini` (your hosts) and `group_vars/all.yml` (your overrides). Defaults
for every variable live in each role's `defaults/main.yml`.

### Inventory

```ini
[servers]
my-server ansible_host=server.example.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_my_server
```

### Variables

`group_vars/all.yml` can be empty (all variables have defaults). Override only
what you need, for example:

```yaml
# Check out a non-default branch:
repo_branch: master

# Use a dedicated operator account instead of the inventory ansible_user.
# operator_user_password must be PRE-HASHED, e.g.:
#   mkpasswd --method=sha-512        (from the `whois` package)
#   openssl passwd -6
# Without operator_user_ssh_key the account cannot SSH until a key is added
# (log in as the ansible_user and add one to the operator's authorized_keys).
operator_user: dhis2admin
operator_user_password: "$6$rounds=...$..."
operator_user_ssh_key: "ssh-ed25519 AAAA... you@host"
```

#### Overridable variables

| Variable | Default | Role | Purpose |
| --- | --- | --- | --- |
| `operator_user` | inventory `ansible_user` | bootstrap | User that owns `deploy_dir`, runs `make`, and is the userns-remap target |
| `operator_user_password` | _(none)_ | bootstrap | **Pre-hashed** password; required only when `operator_user` is a dedicated account |
| `operator_user_ssh_key` | _(none)_ | bootstrap | Optional SSH public key for the dedicated operator account |
| `clone_repo` | `true` | repo | Whether to clone/check out the repo into `deploy_dir` |
| `repo_url` | `https://github.com/dhis2/docker-deployment` | repo | Repo to check out |
| `repo_branch` | `master` | repo | Branch to check out |
| `deploy_dir` | `/opt/dhis2` | bootstrap | Checkout location on the host |
| `allowed_ssh_users` | `[ ubuntu ]` | harden | SSH `AllowUsers` (the `operator_user` is added automatically) |
| `firewall_allowed_ports` | `[ 22, 80, 443 ]` | firewall | Host-facing TCP ports |
| `firewall_allowed_udp_ports` | `[ 51820 ]` | firewall | Host-facing UDP ports (51820 = WireGuard) |

## Usage

1. Create `inventory.ini` and (optionally) `group_vars/all.yml`.
2. Copy your SSH key to the target server: `ssh-copy-id ubuntu@<server>`.
3. Store your sudo password in `./.ansible_become_pass` (gitignored).
4. Run the playbook:

    ```bash
    make deployment
    ```

5. Then, on the server, start the stacks with the `make` workflow (e.g.
   `make start-traefik`, `make start-monitoring`, `make start-vpn`). See the repository root `README.md` and `docs/` for those steps.

## Security notes

- Docker uses user-namespace remapping for least privilege.
- Operators use `sudo docker` rather than membership of the `docker` group.
- The firewall is default-deny; only SSH/HTTP/HTTPS + WireGuard are allowed, plus inter-container traffic on default Docker subnets.
- AppArmor and unattended-upgrades are enabled.

> **Important:** Do **not** use UFW or other firewall frontends alongside this
> setup. Docker bypasses standard host chains, so UFW rules are ignored or may
> conflict. All host and container traffic is managed through the `firewall` role.
> See [roles/firewall/tasks/main.yml](roles/firewall/tasks/main.yml).

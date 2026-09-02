# DHIS2 Server Provisioning - Ansible

This Ansible playbook **provisions and hardens a server** for running the DHIS2
Docker stacks, and optionally **checks out this repository** to the deploy
directory so an operator can run the `make` workflow on the box.

It does **not** start any containers. Starting and managing the stacks (Traefik,
monitoring, WireGuard VPN) and DHIS2 instances is done by an operator with the
`make` workflow in the repository root (`make start-traefik`, `make
start-monitoring`, `make start-vpn`, `make start-instance`, ...).

## Prerequisites

- Ansible installed on the control machine (where you run `make deployment`).
- A target server running Ubuntu 24.04.
- SSH access to the target server with sudo privileges.
- Network access to GitHub on the control machine: `make deployment` installs the shared baseline collection first (see below), along with the `ansible.posix` collection it depends on.

## What it does

**bootstrap**, **firewall** and **harden** live in the `sre.server` collection in
[dhis2-sre/server-baseline](https://github.com/dhis2-sre/server-baseline), so the hardening has one
implementation shared with the other projects that run DHIS2 workloads on plain servers, rather than
a copy each. `make collections` installs it at the tag pinned in
[`../requirements.yml`](../requirements.yml) into a gitignored `collections/` directory;
`make deployment` does it for you. Pinning a tag rather than a branch means the hardening cannot
change under you between two runs of the same playbook.

- **`sre.server.bootstrap`** (shared): installs Docker + Compose and required packages (incl. `make`), optionally creates the operator user, and prepares the deploy directory.
- **`sre.server.firewall`** (shared): configures a default-deny `DOCKER-USER` firewall, allowing only SSH/HTTP/HTTPS, the WireGuard UDP port, and inter-container traffic.
- **`sre.server.harden`** (shared): SSH, kernel and Docker hardening (user-namespace remapping, etc.).
- **`sre.server.baseline`** (shared): the three above, in that order. This is what the playbook lists.
- **deploy** (optional, `clone_repo`): clones/updates this repository into
  `deploy_dir`, owned by the operator user. This one is specific to this project and stays here.

Variables for the shared roles are documented below and defined in their `defaults/main.yml` in that
repository; read its `CHANGELOG.md` before bumping the pin across a major. To try a change to them
before it is tagged, install from somewhere else:
`make deployment SERVER_BASELINE=/path/to/server-baseline`.

## The operator user and `sudo docker`

One user owns `deploy_dir`, runs `make`, and is the Docker user-namespace remap
target. By default this is the inventory `ansible_user` (no extra account is
created). To use a dedicated account, set `docker_user` (see below).

Operators are intentionally **not** added to the root-equivalent `docker` group.
Instead the `make` workflow runs docker via `sudo` by default (explicit and
logged). That's controlled by the `SUDO` variable in the root `Makefile`:

```bash
make start-traefik              # runs: sudo docker compose ...
make start-traefik SUDO=        # no sudo (e.g. dev container, or user in docker group)
```

So `make` will prompt for the operator's sudo password when starting containers.

## Configuration

`inventory/group_vars/all.yml` (your overrides) is **implementation-specific and gitignored** and
must not be committed. It has to live next to the inventory: Ansible reads `group_vars` adjacent to
the inventory or to the playbook and silently ignores it anywhere else. `inventory/production.ini` is a committed template - edit it for your hosts and keep
anything sensitive out of it. Defaults for `deploy` live in `roles/deploy/defaults/main.yml`;
defaults for everything else live in the collection.

### Inventory

```ini
[servers]
my-server-name

[servers:vars]
ansible_host=server.example.com
ansible_user=ubuntu
#ansible_ssh_private_key_file=~/.ssh/id_my_server
```

### Variables

`inventory/group_vars/all.yml` can be empty (all variables have defaults). Override only
what you need, for example:

```yaml
# Check out a non-default branch:
repo_branch: master

# Use a dedicated operator account instead of the inventory ansible_user.
# docker_user_password must be PRE-HASHED, e.g.:
#   mkpasswd --method=sha-512        (from the `whois` package)
#   openssl passwd -6
# Without docker_user_ssh_key the account cannot SSH until a key is added
# (log in as the ansible_user and add one to the operator's authorized_keys).
docker_user: dhis2admin
docker_user_password: "$6$rounds=...$..."
docker_user_ssh_key: "ssh-ed25519 AAAA... you@host"
```

#### Overridable variables

| Variable | Default | Owned by | Purpose |
| --- | --- | --- | --- |
| `docker_user` | inventory `ansible_user` | collection | User that owns `deploy_dir`, runs `make`, and is the userns-remap target |
| `docker_user_password` | _(none)_ | collection | **Pre-hashed** password; required only when `docker_user` is a dedicated account |
| `docker_user_ssh_key` | _(none)_ | collection | Optional SSH public key for the dedicated operator account |
| `allowed_ssh_users` | `[ ubuntu ]` | collection | SSH `AllowUsers` (the `docker_user` is added automatically) |
| `firewall_allowed_ports` | `[ 22, 80, 443 ]` | collection | Host-facing TCP ports |
| `firewall_allowed_udp_ports` | `[ 51820 ]` | collection | Host-facing UDP ports (51820 = WireGuard) |
| `clone_repo` | `true` | here | Whether to clone/check out the repo into `deploy_dir` |
| `repo_url` | `https://github.com/dhis2/docker-deployment` | here | Repo to check out |
| `repo_branch` | `master` | here | Branch to check out |

`deploy_dir` is `/opt/dhis2`, set in [`playbooks/deploy.yml`](playbooks/deploy.yml) rather than by
the collection, whose own default is `/opt/deploy`. It is a play variable, so `group_vars` cannot
override it - change it in the playbook.

## Usage

1. Edit `inventory/production.ini` and (optionally) create `inventory/group_vars/all.yml`.
2. Copy your SSH key to the target server: `ssh-copy-id ubuntu@<server>`.
3. Store your sudo password in `./.ansible_become_pass` (gitignored).
4. Run the playbook:

    ```bash
    make deployment
    ```

    That installs the pinned collection into `collections/` first. To install it without provisioning anything, run `make collections`.

5. Then, on the server, start the stacks with the `make` workflow (e.g.
   `make start-traefik`, `make start-monitoring`, `make start-vpn`). See the repository root `README.md` and `docs/` for those steps.

## Security notes

- Docker uses user-namespace remapping for least privilege.
- Operators use `sudo docker` rather than membership of the `docker` group.
- The firewall is default-deny; only SSH/HTTP/HTTPS + WireGuard are allowed, plus inter-container traffic on default Docker subnets.
- AppArmor and unattended-upgrades are enabled.

> **Important:** Do **not** use UFW or other firewall frontends alongside this
> setup. Docker bypasses standard host chains, so UFW rules are ignored or may
> conflict. All host and container traffic is managed through the collection's `firewall` role.
> See [the firewall role](https://github.com/dhis2-sre/server-baseline/blob/master/roles/firewall/tasks/main.yml).

# DHIS2 Server Provisioning - Ansible

This Ansible playbook **provisions and hardens a server** for running the DHIS2
Docker stacks, and optionally **checks out this repository** to the deploy
directory so an operator can run the `make` workflow on the box.

It does **not** start any containers. Starting and managing the stacks (Traefik,
monitoring, WireGuard VPN) and DHIS2 instances is done by an operator with the
`make` workflow in the repository root (`make start-traefik`, `make
start-monitoring`, `make start-vpn`, `make start-instance`, ...).

## Prerequisites

- Ansible installed on the control machine (where you run `make provision`).
- A target server running Ubuntu 24.04 or 26.04.
- SSH access to the target server with sudo privileges.
- Network access to GitHub on the control machine: `make provision` installs the shared baseline collection first (see below), along with the `ansible.posix` and `community.general` collections it depends on.

## What it does

**bootstrap**, **firewall** and **harden** live in the `sre.server` collection in
[dhis2-sre/server-baseline](https://github.com/dhis2-sre/server-baseline), so the hardening has one
implementation shared with the other projects that run DHIS2 workloads on plain servers, rather than
a copy each. `make collections` installs it at the tag pinned in
[`../requirements.yml`](../requirements.yml) into a gitignored `collections/` directory;
`make provision` does it for you. Pinning a tag rather than a branch means the hardening cannot
change under you between two runs of the same playbook.

- **`sre.server.bootstrap`** (shared): installs Docker + Compose and required packages (incl. `make`), optionally creates the operator user, and prepares the deploy directory.
- **`sre.server.firewall`** (shared): a default-deny ufw firewall for services on the host, plus a default-deny `DOCKER-USER` chain for published container ports, opening only SSH, HTTP/HTTPS and the WireGuard UDP port.
- **`sre.server.harden`** (shared): SSH, kernel and Docker hardening (SSH on port 822, user-namespace remapping, etc.).
- **`sre.server.baseline`** (shared): the three above, in that order. This is what the playbook lists.
- **deploy** (optional, `clone_repo`): clones/updates this repository into
  `deploy_dir`, owned by the operator user. This one is specific to this project and stays here.

Variables for the shared roles are documented below and defined in their `defaults/main.yml` in that
repository; read its `CHANGELOG.md` before bumping the pin across a major. To try a change to them
before it is tagged, install from somewhere else:
`make provision SERVER_BASELINE=/path/to/server-baseline`.

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
#ansible_port=822   # after the first run, see Usage
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
| `ssh_port` | `822` | collection | Port sshd listens on. The firewall opens it, and the port Ansible is connected on, by itself |
| `firewall_allowed_ports` | `[ 80, 443 ]` | collection | TCP ports reachable from outside, for host services and published container ports alike. Leave SSH out |
| `firewall_allowed_udp_ports` | `[ 51820 ]` | collection | UDP ports, opened the same way (51820 = WireGuard) |
| `firewall_docker_bridges` | `[ docker0, br-+ ]` | collection | Bridges containers sit on; traffic leaving them is allowed |
| `clone_repo` | `true` | here | Whether to clone/check out the repo into `deploy_dir` |
| `repo_url` | `https://github.com/dhis2/docker-deployment` | here | Repo to check out |
| `repo_branch` | `master` | here | Branch to check out |

`deploy_dir` is `/opt/dhis2`, set in [`playbooks/provision.yml`](playbooks/provision.yml) rather than by
the collection, whose own default is `/opt/deploy`. It is a play variable, so `group_vars` cannot
override it - change it in the playbook.

## Usage

1. Edit `inventory/production.ini` and (optionally) create `inventory/group_vars/all.yml`.
2. Copy your SSH key to the target server: `ssh-copy-id ubuntu@<server>`.
3. Store your sudo password in `./.ansible_become_pass` (gitignored).
4. Run the playbook:

    ```bash
    make provision
    ```

    That installs the pinned collection into `collections/` first. To install it without provisioning anything, run `make collections`.

5. The first run connects on port 22 and moves SSH to `ssh_port` (822), keeping 22 open alongside it. Open 822 in any provider firewall, set `ansible_port=822` in the inventory and run `make provision` again, which closes 22. To stay on 22, set `ssh_port: 22` before the first run instead.
6. Then, on the server, start the stacks with the `make` workflow (e.g.
   `make start-traefik`, `make start-monitoring`, `make start-vpn`). See the repository root `README.md` and `docs/` for those steps.

## Security notes

- Docker uses user-namespace remapping for least privilege.
- Operators use `sudo docker` rather than membership of the `docker` group.
- The firewall is default-deny, for services on the host and published container ports alike; only SSH, HTTP/HTTPS and WireGuard are open. Containers reach each other and the internet, but reach services on the host only on the listed ports.
- AppArmor and unattended-upgrades are enabled.

The collection's `firewall` role manages ufw. Rules you add by hand with `ufw allow` survive its runs,
but do not add another firewall frontend or `iptables-persistent`. See
[the firewall role](https://github.com/dhis2-sre/server-baseline/blob/master/roles/firewall/tasks/main.yml).

### Upgrading a server provisioned with `sre.server` 1.x

`sre.server` 2.0.0 replaces the firewall with ufw and moves SSH to port 822. Before the first run on
an existing server, check `sudo ss -tulpn` for services listening on the host: any port not in the
lists above becomes unreachable. Then follow step 5 of [Usage](#usage): run, open 822 at the provider,
set `ansible_port=822`, run again. See the
[server-baseline changelog](https://github.com/dhis2-sre/server-baseline/blob/master/CHANGELOG.md).

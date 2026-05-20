# DHIS2 Docker Deployment Ansible Playbook

This Ansible playbook provisions a host for running the DHIS2 Docker stack. It installs Docker, applies firewall and security hardening, and clones this repository onto the host. Starting the stack itself is done manually with the `make start-*` targets from the cloned working tree, not by Ansible.

## Features

- **Infrastructure Bootstrapping**: Installs required system packages including Docker and Docker Compose
- **Security Hardening**: Applies system hardening based on the microk8s-playbook harden.yaml, adapted for Docker
- **Repository Checkout**: Clones the deployment repository to `deploy_dir`
- **Modularity**: Uses Ansible roles for easy extension and maintenance
- **Idempotency**: Safe to run multiple times

## Prerequisites (recommendations)

- Ansible installed on the control machine
- Target server with Ubuntu 24.04
- SSH access to the target server with sudo privileges

## Configuration

Edit `group_vars/all.yml` to customize:

- `repo_url`: Repository to clone onto the host
- `deploy_dir`: Where to clone it
- `firewall_allowed_ports`: Host-facing TCP ports to open
- `allowed_ssh_users`: Users allowed to SSH in
- `docker_user` / `docker_group` / `docker_home`: Account that owns the Docker workload

## Usage

1. Update the inventory file `inventory.ini` according to your needs

2. Copy your public SSH key to the target server

    ```bash
    ssh-copy-id ubuntu@<your server ip>
    ```

3. Store your user's sudo password in `./.ansible_become_pass`

4. Run the playbook:

    ```bash
    make deployment
    ```

5. Once provisioning finishes, SSH to the host and start the stacks from the cloned repo using the `make start-*` targets (see the repo's top-level README).

## Roles

- **bootstrap**: Installs Docker, creates users, sets up directories
- **firewall**: Configures firewall rules for Docker and host-facing ports
- **harden**: Applies security hardening (SSH, kernel, Docker config)
- **deploy**: Clones the deployment repository to `deploy_dir`

## Security Notes

- Docker is configured with user namespace remapping for least privilege
- Firewall rules are configured to deny all by default and only allow SSH, HTTP, HTTPS and inter-container communication only on default subnets
- AppArmor is enabled
- Unattended-upgrades are enabled

The above is only a subset of the security hardening that is applied. For more information, see the [firewall](roles/firewall/tasks/main.yml) and [harden](roles/harden/tasks/main.yml) roles.

### Firewall Management

All firewall rules for Docker and host-facing ports are managed by the `firewall` role. See [roles/firewall/tasks/main.yml](roles/firewall/tasks/main.yml) for more details.

⚠️ **Important:** Do **not** use UFW or other firewall frontends alongside this setup. Docker bypasses standard host chains (INPUT/OUTPUT), so UFW rules are ignored or may conflict. All host and container traffic should be managed exclusively through this Ansible role.

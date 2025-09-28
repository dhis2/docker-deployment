# DHIS2 Docker Deployment Ansible Playbook

This Ansible playbook automates the deployment of the DHIS2 Docker stack.

## Features

- **Infrastructure Bootstrapping**: Installs required system packages including Docker and Docker Compose
- **Security Hardening**: Applies system hardening based on the microk8s-playbook harden.yaml, adapted for Docker
- **Deployment Automation**: Clones the repository, generates .env file, and deploys with selected overlays
- **Modularity**: Uses Ansible roles for easy extension and maintenance
- **Idempotency**: Safe to run multiple times

## Prerequisites (recommendations)

- Ansible installed on the control machine
- Target server with Ubuntu 24.04
- SSH access to the target server with sudo privileges
- Environment variables set: `GEN_APP_HOSTNAME` and `GEN_LETSENCRYPT_ACME_EMAIL`

## Configuration

Edit `group_vars/all.yml` to customize:

- `app_hostname`: Application hostname (set via env var)
- `letsencrypt_email`: Let's Encrypt email (set via env var)
- `overlays`: List of overlays to enable, e.g., `['monitoring']`
- Other variables as needed

## Usage

1. Set environment variables:

    ```bash
    export GEN_APP_HOSTNAME=your.domain.com
    export GEN_LETSENCRYPT_ACME_EMAIL=your.email@example.com
    ```

2. Update the inventory file `inventory.ini` according to your needs

3. Run the playbook:

    ```bash
    make deployment
    ```

## Roles

- **bootstrap**: Installs Docker, creates users, sets up directories
- **firewall**: Configures firewall rules for Docker and host-facing ports
- **harden**: Applies security hardening (SSH, kernel, Docker config)
- **deploy**: Clones repo, generates .env, runs docker-compose

## Security Notes

- Docker is configured with user namespace remapping for least privilege
- Firewall rules are configured to deny all by default and only allow SSH, HTTP, HTTPS and inter-container communication
  only on default subnets
- AppArmor is enabled
- Unattended-upgrades are enabled
- Secrets are handled via environment variables and .env file

The above is only a subset of the security hardening that is applied. For more information, see
the [firewall](roles/firewall/tasks/main.yml) and [harden](roles/harden/tasks/main.yml) roles.

### Firewall Management

All firewall rules for Docker and host-facing ports are managed by the `firewall` role.
See [roles/firewall/tasks/main.yml](roles/firewall/tasks/main.yml) for more details.

⚠️ **Important:** Do **not** use UFW or other firewall frontends alongside this setup. Docker bypasses standard host
chains (INPUT/OUTPUT), so UFW rules are ignored or may conflict. All host and container traffic should be managed
exclusively through this Ansible role.

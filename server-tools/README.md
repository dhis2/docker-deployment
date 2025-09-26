# DHIS2 Docker Deployment Ansible Playbook

This Ansible playbook automates the deployment of the DHIS2 Docker stack.

## Features

- **Infrastructure Bootstrapping**: Installs required system packages including Docker and Docker Compose
- **Security Hardening**: Applies system hardening based on the microk8s-playbook harden.yaml, adapted for Docker
- **Deployment Automation**: Clones the repository, generates .env file, and deploys with selected overlays
- **Modularity**: Uses Ansible roles for easy extension and maintenance
- **Idempotency**: Safe to run multiple times

## Prerequisites

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

2. Create an inventory file (e.g., `inventory.ini`):

    ```ini
    [servers]
    your-server ansible_host=your-server-ip ansible_user=ubuntu
    ```

3. Run the playbook:

    ```bash
    ansible-playbook -i inventory.ini site.yml --ask-become-pass
    ```

## Roles

- **bootstrap**: Installs Docker, creates users, sets up directories
- **harden**: Applies security hardening (SSH, kernel, Docker config)
- **deploy**: Clones repo, generates .env, runs docker-compose

## Security Notes

- Docker is configured with user namespace remapping for least privilege
- AppArmor is enabled where possible
- UFW firewall allows only necessary ports
- Secrets are handled via environment variables and .env file

## Testing

The playbook includes basic health checks for Docker Compose services. For thorough testing, monitor logs and service
status post-deployment.

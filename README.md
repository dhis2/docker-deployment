# Docker Deployment

Docker production deployment of the DHIS2 application

## Quick Start

### Configure Environment

Generate a new `.env` file by executing the following command

```shell
./generate_env.sh
```

Potentially adjust the generated `.env` file to your needs. However, it's highly recommended not to change the generated values of the password variables.

### Automatic Certificate Management Environment

The acme file needs to be owned, only writable, by the same user running Traefik

```shell
touch ./traefik/acme.json
sudo chown 65534:65534 ./traefik/acme.json
sudo chmod 600 ./traefik/acme.json
```

### Launch the application

```shell
docker compose up
```

Open http://dhis2-127-0-0-1.nip.io in your favourite browser.

## Overlays

### Traefik Dashboard

The Traefik dashboard can be enabled by launching the application with the following command

```shell
docker compose -f docker-compose.yml -f overlays/docker-compose.traefik-dashboard.yml up
```

## Backup and Restore

Backups are stored in the `./backups` directory.

We support backup of both the database and the file storage.

### Backup

A complete backup of both database and file storage can be created by executing the following command

```shell
make backup
```

#### Backup Database

The database can be backed up in two different formats: `custom` and `plain`. The default format is `custom` but it can be changed by setting the `POSTGRES_BACKUP_FORMAT` environment variable to either value.

A backup of the database can be created by executing the following command

```shell
make backup-database
```

#### Backup File Storage

A backup of the file storage can be created by executing the following command

```shell
make backup-file-storage
```

### Restore

TODO

## Set up development environment

### Prerequisites

- Python 3.11+
- Make

```shell
make init
```

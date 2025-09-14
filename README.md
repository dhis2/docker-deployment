# Docker Deployment

Docker production deployment of the DHIS2 application

## Quick Start

Generate a new `.env` file by executing the following command

```shell
./generate_env.sh
```

Potentially adjust the generated `.env` file to your needs. However, it's highly recommended not to change the generated values of the password variables.

Launch the application by executing the following command

```shell
docker compose up
```

Open http://dhis2-127-0-0-1.nip.io in your favourite browser.

### Prerequisites

- Python 3.11+
- Node.js 20+
- Make
- Docker & Docker Compose

### Set up development environment

```shell
make init
```

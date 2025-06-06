# Docker Deployment

Docker production deployment of the DHIS2 application

# Quick Start

Copy .env.example to .env and edit it to match your environment.

```shell
docker compose up
```

Open http://dhis2-127-0-0-1.nip.io in your favourite browser.

# TODO

* Implement pipeline with basic smoke test
* Pre-commit hooks?
* Pinned version? Should we use major, minor and patch?
* TLS using Let's Encrypt
* Database backup
* Database restore
* Monitoring

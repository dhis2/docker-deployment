"""Internal routes must not answer on the public HTTPS listener.

Knowing the server's address and an internal hostname is enough to reach a
router placed on the public 'websecure' entrypoint: *.internal DNS and the
self-signed certificates are conveniences for VPN clients, not access controls.
These tests pin the internal routes to the unpublished 'internal' entrypoint.
"""

import os
import socket
import subprocess

import pytest

from test_helpers import PROJECT_NAME, container_name

CURL_IMAGE = "curlimages/curl:8.11.1"
PROXY_NETWORK = "proxy"
PUBLIC_HTTPS_PORT = 443
INTERNAL_ENTRYPOINT_PORT = 8443
DISCOVERY_PROBE_ADDRESS = ("192.0.2.1", 9)

GRAFANA_HOSTNAME = "grafana.internal"
GLOWROOT_HOSTNAME = f"{PROJECT_NAME}.glowroot.internal"
INTERNAL_HOSTNAMES = [GRAFANA_HOSTNAME, GLOWROOT_HOSTNAME]

CURL_OPTIONS = [
    "--noproxy", "*",
    "--insecure",
    "--silent",
    "--show-error",
    "--output", "/dev/null",
    "--write-out", "%{http_code}",
    "--max-time", "15",
]


def _host_addresses() -> list[str]:
    """Addresses an outside caller could use to reach the published HTTPS port:
    loopback plus the address of the interface holding the default route."""
    addresses = {"127.0.0.1"}
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(DISCOVERY_PROBE_ADDRESS)
        addresses.add(probe.getsockname()[0])
    except OSError:
        pass
    finally:
        probe.close()
    return sorted(addresses)


def _status(command: list[str], timeout: int = 120) -> int:
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        raise AssertionError(f"Request failed: {' '.join(command)}\n{result.stderr}")
    return int(result.stdout.strip())


def _status_from_public_listener(hostname: str, address: str, path: str = "/") -> int:
    """Request the hostname over the published HTTPS port at the given address,
    supplying the hostname as both Host header and TLS SNI. This is what a caller
    who knows only the server's address can do, without DNS or VPN membership."""
    return _status([
        "curl", *CURL_OPTIONS,
        "--resolve", f"{hostname}:{PUBLIC_HTTPS_PORT}:{address}",
        f"https://{hostname}:{PUBLIC_HTTPS_PORT}{path}",
    ])


def _status_from_internal_entrypoint(hostname: str) -> int:
    """Request the hostname on Traefik's unpublished internal entrypoint from the
    proxy network, the path the WireGuard socat forwarder takes."""
    return _status([
        "docker", "run", "--rm", "--network", PROXY_NETWORK, CURL_IMAGE,
        *CURL_OPTIONS,
        "--connect-to",
        f"{hostname}:{INTERNAL_ENTRYPOINT_PORT}:traefik:{INTERNAL_ENTRYPOINT_PORT}",
        f"https://{hostname}:{INTERNAL_ENTRYPOINT_PORT}/",
    ])


@pytest.mark.order(13)
@pytest.mark.parametrize("hostname", INTERNAL_HOSTNAMES)
def test_internal_hostname_is_not_served_on_the_public_listener(hostname: str):
    for address in _host_addresses():
        status = _status_from_public_listener(hostname, address)
        assert status == 404, (
            f"{hostname} answered {status} on the public HTTPS port at {address}. "
            "Its router must use the unpublished 'internal' entrypoint."
        )


@pytest.mark.order(14)
@pytest.mark.parametrize("hostname", INTERNAL_HOSTNAMES)
def test_internal_hostname_is_served_on_the_internal_entrypoint(hostname: str):
    status = _status_from_internal_entrypoint(hostname)
    assert status != 404, (
        f"{hostname} is not routed on the internal entrypoint, so VPN clients "
        "cannot reach it either."
    )


@pytest.mark.order(15)
def test_public_hostname_is_still_served_on_the_public_listener():
    hostname = os.environ["APP_HOSTNAME"]
    for address in _host_addresses():
        status = _status_from_public_listener(hostname, address, "/login.html")
        assert status == 200, (
            f"{hostname} answered {status} on the public HTTPS port at {address}."
        )


@pytest.mark.order(16)
def test_internal_entrypoint_is_not_published_to_the_host():
    published = subprocess.run(
        ["docker", "port", container_name("traefik")],
        capture_output=True, text=True, check=True,
    ).stdout
    assert str(INTERNAL_ENTRYPOINT_PORT) not in published, (
        f"Traefik publishes the internal entrypoint to the host:\n{published}"
    )

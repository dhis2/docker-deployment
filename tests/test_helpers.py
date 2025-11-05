import json
import os
import subprocess
import time
from typing import Optional, Dict


def run_make_command(command: str, env_vars: Optional[Dict[str, str]] = None, check: bool = True) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)

    cmd_parts = ["make", "--no-print-directory"] + command.split()

    result = subprocess.run(cmd_parts, env=env, capture_output=True, text=True)

    if check and result.returncode != 0:
        print(f"Command failed: {' '.join(cmd_parts)}")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")
        result.check_returncode()

    return result


def wait_for_service_healthy(service_name: str, max_attempts: int = 30, check_interval: int = 5) -> None:
    print(f"Waiting for {service_name} to be healthy...")

    for attempt in range(1, max_attempts + 1):
        result = subprocess.run([
            "docker", "compose", "ps", service_name, "--format", "json"
        ], capture_output=True, text=True)

        if result.returncode == 0 and '"Health":"healthy"' in result.stdout:
            print(f"{service_name} is healthy")
            return

        print(f"Attempt {attempt}/{max_attempts}: {service_name} not healthy yet...")
        time.sleep(check_interval)

    raise Exception(f"{service_name} failed to become healthy after {max_attempts} attempts")


def get_services() -> list[dict]:
    result = subprocess.run(
        ["docker", "compose", "ps", "--format", "json"],
        capture_output=True,
        text=True,
        check=True
    )
    return [json.loads(line) for line in result.stdout.strip().split("\n") if line]


def assert_no_services_unhealthy() -> None:
    services = get_services()
    unhealthy = [service["Service"] for service in services if service.get("Health") == "unhealthy"]
    assert not unhealthy, f"Unhealthy services: {(unhealthy)}"


def assert_no_services_running() -> None:
    services = get_services()
    running = [s["Service"] for s in services if s.get("State") == "running"]
    assert not running, f"Services still running: {running}"

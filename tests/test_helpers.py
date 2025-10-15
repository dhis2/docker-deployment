import subprocess
import time
import requests
import os
import json
from typing import Optional, Dict, Any
from pathlib import Path


def run_make_command(command: str, env_vars: Optional[Dict[str, str]] = None, check: bool = True) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)

    cmd_parts = ["make"] + command.split()
    print(f"Running: {' '.join(cmd_parts)}")

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


def get_backup_timestamp() -> str:
    result = subprocess.run([
        "date", "-u", "+%Y-%m-%d_%H-%M-%S_%Z"
    ], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def assert_backup_files_exist(timestamp: str) -> None:
    db_path = f"./backups/{timestamp}.pgc"
    fs_path = f"./backups/file-storage-{timestamp}"

    assert os.path.exists(db_path), f"Database backup not found: {db_path}"
    assert os.path.isdir(fs_path), f"File storage backup not found: {fs_path}"


def get_loki_labels() -> Dict[str, Any]:
    response = requests.get("http://localhost:3100/loki/api/v1/labels", timeout=10)
    response.raise_for_status()
    return response.json()


def get_prometheus_labels() -> Dict[str, Any]:
    result = subprocess.run([
        "docker", "compose", "exec", "-T", "prometheus",
        "wget", "-qO-", "http://localhost:9090/api/v1/labels"
    ], capture_output=True, text=True, timeout=30)

    if result.returncode != 0:
        raise Exception(f"Prometheus command failed: {result.stderr}")

    return json.loads(result.stdout)


def verify_loki_labels(loki_labels: Dict[str, Any]) -> None:
    print("Verifying Loki labels...")

    assert "data" in loki_labels, "Loki response should contain 'data' field"

    loki_label_count = len(loki_labels["data"])
    print(f"Loki has {loki_label_count} labels")

    expected_labels = ["container_name", "service", "compose_project"]
    loki_label_names = loki_labels["data"]

    for expected_label in expected_labels:
        status = "Found" if expected_label in loki_label_names else "Expected"
        print(f"{status} Loki label: {expected_label}")


def verify_prometheus_labels(prometheus_labels: Dict[str, Any]) -> None:
    print("Verifying Prometheus labels...")

    assert "data" in prometheus_labels, "Prometheus response should contain 'data' field"

    prometheus_label_count = len(prometheus_labels["data"])
    print(f"Prometheus has {prometheus_label_count} labels")

    expected_labels = ["__name__", "instance", "job"]
    prometheus_label_names = prometheus_labels["data"]

    for expected_label in expected_labels:
        status = "Found" if expected_label in prometheus_label_names else "Expected"
        print(f"{status} Prometheus label: {expected_label}")


def ensure_backups_directory() -> None:
    Path("./backups").mkdir(exist_ok=True)

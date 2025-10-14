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


def wait_for_service(service_name: str, max_attempts: int = 30, check_interval: int = 10) -> bool:
    print(f"Waiting for {service_name} to be ready...")

    for attempt in range(1, max_attempts + 1):
        try:
            result = subprocess.run([
                "docker", "compose", "ps", service_name
            ], capture_output=True, text=True, check=True)

            if "healthy" in result.stdout or "Up" in result.stdout:
                print(f"{service_name} is ready")
                return True

        except subprocess.CalledProcessError:
            pass

        print(f"Attempt {attempt}/{max_attempts}: {service_name} not ready yet...")
        time.sleep(check_interval)

    print(f"{service_name} failed to become ready after {max_attempts} attempts")
    return False


def wait_for_app_ready(app_hostname: str, max_attempts: int = 30, check_interval: int = 5) -> bool:
    print(f"Waiting for DHIS2 application at {app_hostname} to be ready...")

    for attempt in range(1, max_attempts + 1):
        try:
            response = requests.get(f"https://{app_hostname}/dhis-web-login/",
                                  verify=False, timeout=10)
            if response.status_code == 200:
                print(f"DHIS2 application is ready")
                return True
        except requests.exceptions.RequestException:
            pass

        print(f"Attempt {attempt}/{max_attempts}: DHIS2 application not ready yet...")
        time.sleep(check_interval)

    print(f"DHIS2 application failed to become ready after {max_attempts} attempts")
    return False


def get_backup_timestamp() -> str:
    result = subprocess.run([
        "date", "-u", "+%Y-%m-%d_%H-%M-%S_%Z"
    ], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def cleanup_backups(backup_timestamp: str) -> None:
    print("Cleaning up backup files...")
    try:
        db_backup = f"./backups/{backup_timestamp}.pgc"
        if os.path.exists(db_backup):
            os.remove(db_backup)

        fs_backup = f"./backups/file-storage-{backup_timestamp}"
        if os.path.exists(fs_backup):
            subprocess.run(["rm", "-rf", fs_backup], check=True)

    except Exception as e:
        print(f"Failed to cleanup backup files: {e}")


def backup_paths_for(timestamp: str) -> Dict[str, str]:
    return {
        "db": f"./backups/{timestamp}.pgc",
        "fs": f"./backups/file-storage-{timestamp}",
    }


def assert_backup_files_exist(timestamp: str) -> None:
    paths = backup_paths_for(timestamp)
    missing: list[str] = []
    if not os.path.exists(paths["db"]):
        missing.append(paths["db"])
    if not os.path.isdir(paths["fs"]):
        missing.append(paths["fs"])
    if missing:
        raise AssertionError(
            "Expected backup artifacts not found: " + ", ".join(missing)
        )


def get_loki_labels() -> Dict[str, Any]:
    try:
        response = requests.get("http://localhost:3100/loki/api/v1/labels", timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to get Loki labels: {e}")


def get_prometheus_labels() -> Dict[str, Any]:
    try:
        result = subprocess.run([
            "docker", "compose", "exec", "-T", "prometheus",
            "wget", "-qO-", "http://localhost:9090/api/v1/labels"
        ], capture_output=True, text=True, timeout=30)

        if result.returncode != 0:
            raise Exception(f"Prometheus command failed: {result.stderr}")

        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        raise Exception("Prometheus labels endpoint timed out")
    except json.JSONDecodeError as e:
        raise Exception(f"Failed to parse Prometheus response: {e}")
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to execute Prometheus command: {e}")


def verify_monitoring_labels(loki_labels: Dict[str, Any], prometheus_labels: Dict[str, Any]) -> None:
    print("Verifying monitoring labels...")

    if "data" not in loki_labels:
        raise AssertionError("Loki response should contain 'data' field")

    loki_label_count = len(loki_labels["data"])
    print(f"Loki has {loki_label_count} labels")

    if "data" not in prometheus_labels:
        raise AssertionError("Prometheus response should contain 'data' field")

    prometheus_label_count = len(prometheus_labels["data"])
    print(f"Prometheus has {prometheus_label_count} labels")

    expected_loki_labels = ["container_name", "service", "compose_project"]
    expected_prometheus_labels = ["__name__", "instance", "job"]

    loki_label_names = [label for label in loki_labels["data"]]
    prometheus_label_names = [label for label in prometheus_labels["data"]]

    for expected_label in expected_loki_labels:
        if expected_label in loki_label_names:
            print(f"Found expected Loki label: {expected_label}")
        else:
            print(f"Expected Loki label not found: {expected_label}")

    for expected_label in expected_prometheus_labels:
        if expected_label in prometheus_label_names:
            print(f"Found expected Prometheus label: {expected_label}")
        else:
            print(f"Expected Prometheus label not found: {expected_label}")


def ensure_backups_directory() -> None:
    Path("./backups").mkdir(exist_ok=True)

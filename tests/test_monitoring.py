import pytest
import requests
import subprocess
import os
from test_helpers import (
    get_loki_labels, get_prometheus_labels, verify_loki_labels, verify_prometheus_labels
)

@pytest.mark.order(8)
def test_monitoring_services_health():
    print("\n=== Step 8: Testing Monitoring Services Health ===")

    response = requests.get("http://localhost:3100/ready", timeout=10)
    assert response.status_code == 200, f"Loki health check failed: {response.status_code}"

    result = subprocess.run([
        "docker", "compose", "exec", "-T", "prometheus",
        "wget", "-qO-", "http://localhost:9090/-/healthy"
    ], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, f"Prometheus health check failed: {result.stderr}"

    app_hostname = os.getenv("APP_HOSTNAME")
    grafana_url = f"https://grafana.{app_hostname}/api/health"
    response = requests.get(grafana_url, timeout=10, verify=False)
    assert response.status_code == 200, f"Grafana health check failed: {response.status_code}"


@pytest.mark.order(9)
def test_monitoring_labels():
    print("\n=== Step 9: Testing Monitoring Labels ===")

    loki_labels = get_loki_labels()
    verify_loki_labels(loki_labels)

    prometheus_labels = get_prometheus_labels()
    verify_prometheus_labels(prometheus_labels)

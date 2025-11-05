import pytest
import json
import subprocess
import requests
from pydantic import BaseModel
from typing import List


@pytest.mark.order(8)
def test_loki_labels():
    loki_labels = get_loki_labels()

    expected_labels = {"container_name", "compose_service", "compose_project"}
    actual_labels = set(loki_labels.data)

    assert expected_labels <= actual_labels


@pytest.mark.order(9)
def test_prometheus_labels():
    prometheus_labels = get_prometheus_labels()

    expected_labels = {"__name__", "instance", "job"}
    actual_labels = set(prometheus_labels.data)

    assert expected_labels <= actual_labels

class Labels(BaseModel):
    data: List[str]


def get_loki_labels() -> Labels:
    response = requests.get("http://localhost:3100/loki/api/v1/labels", timeout=10)
    response.raise_for_status()
    return Labels.model_validate(response.json())


def get_prometheus_labels() -> Labels:
    result = subprocess.run([
        "docker", "compose", "exec", "-T", "prometheus",
        "wget", "-qO-", "http://localhost:9090/api/v1/labels"
    ], capture_output=True, text=True, timeout=30)

    if result.returncode != 0:
        raise Exception(f"Prometheus command failed: {result.stderr}")

    return Labels.model_validate(json.loads(result.stdout))

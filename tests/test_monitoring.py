import pytest
import json
import subprocess
import requests
from dataclasses import dataclass
from typing import List, Dict, Any
from test_helpers import get_loki_labels, get_prometheus_labels


@pytest.mark.order(8)
def test_loki_labels():
    print("\n=== Testing Loki Labels ===")

    loki_labels = get_loki_labels()

    expected_labels = {"container_name", "service", "compose_project"}
    actual_labels = set(loki_labels.data)

    missing_labels = expected_labels - actual_labels
    assert not missing_labels, f"Missing required Loki labels: {missing_labels}"

    print(f"Loki has {len(actual_labels)} labels")
    print(f"All required labels present: {expected_labels}")


@pytest.mark.order(9)
def test_prometheus_labels():
    print("\n=== Testing Prometheus Labels ===")

    prometheus_labels = get_prometheus_labels()

    expected_labels = {"__name__", "instance", "job"}
    actual_labels = set(prometheus_labels.data)

    missing_labels = expected_labels - actual_labels
    assert not missing_labels, f"Missing required Prometheus labels: {missing_labels}"

    print(f"Prometheus has {len(actual_labels)} labels")
    print(f"All required labels present: {expected_labels}")

@dataclass
class LabelsResponse:
    data: List[str]

    @classmethod
    def from_dict(cls, response_dict: Dict[str, Any]) -> "LabelsResponse":
        if "data" not in response_dict:
            raise ValueError("Response missing required 'data' field")
        return cls(data=response_dict["data"])


def get_loki_labels() -> LabelsResponse:
    response = requests.get("http://localhost:3100/loki/api/v1/labels", timeout=10)
    response.raise_for_status()
    return LabelsResponse.from_dict(response.json())


def get_prometheus_labels() -> LabelsResponse:
    result = subprocess.run([
        "docker", "compose", "exec", "-T", "prometheus",
        "wget", "-qO-", "http://localhost:9090/api/v1/labels"
    ], capture_output=True, text=True, timeout=30)

    if result.returncode != 0:
        raise Exception(f"Prometheus command failed: {result.stderr}")

    return LabelsResponse.from_dict(json.loads(result.stdout))

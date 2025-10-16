import pytest
from test_helpers import (
    get_loki_labels, get_prometheus_labels, verify_loki_labels, verify_prometheus_labels
)

@pytest.mark.order(8)
def test_monitoring_labels():
    print("\n=== Testing Monitoring Labels ===")

    loki_labels = get_loki_labels()
    verify_loki_labels(loki_labels)

    prometheus_labels = get_prometheus_labels()
    verify_prometheus_labels(prometheus_labels)

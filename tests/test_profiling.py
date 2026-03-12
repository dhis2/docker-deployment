import pytest
import json
import subprocess
from pydantic import BaseModel
from typing import List


@pytest.mark.order(11)
def test_tempo_receiving_traces():
    """Verify Tempo has received traces from DHIS2."""
    tags_response = get_tempo_tags()

    # Find the intrinsic scope which contains built-in trace attributes
    intrinsic_scope = next(
        (scope for scope in tags_response.scopes if scope.name == "intrinsic"), None
    )

    assert intrinsic_scope is not None, "Intrinsic scope not found in Tempo tags"

    # These are standard OpenTelemetry intrinsic attributes that should be present
    expected_tags = {"name", "status", "kind"}
    actual_tags = set(intrinsic_scope.tags)

    assert expected_tags <= actual_tags, (
        f"Expected intrinsic tags {expected_tags} not found. Actual tags: {actual_tags}"
    )


@pytest.mark.order(12)
def test_dhis2_service_in_traces():
    """Verify DHIS2 service appears in trace data."""
    service_names = get_tempo_service_names()

    # The DHIS2 app is instrumented with otel.service.name=dhis2
    assert "dhis2" in service_names.tagValues, (
        f"Expected 'dhis2' service not found in traces. "
        f"Available services: {service_names.tagValues}"
    )


class TagScope(BaseModel):
    name: str
    tags: List[str]


class SearchTagsV2Response(BaseModel):
    scopes: List[TagScope]


class TagValues(BaseModel):
    tagValues: List[str]


def get_tempo_ready() -> bool:
    """Check if Tempo is ready by querying the /ready endpoint."""
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "tempo",
            "wget",
            "-qO-",
            "--spider",
            "http://localhost:3200/ready",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )

    return result.returncode == 0


def get_tempo_tags() -> SearchTagsV2Response:
    """Query Tempo for available search tags grouped by scope."""
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "tempo",
            "wget",
            "-qO-",
            "http://localhost:3200/api/v2/search/tags",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )

    if result.returncode != 0:
        raise Exception(f"Tempo tags command failed: {result.stderr}")

    return SearchTagsV2Response.model_validate(json.loads(result.stdout))


def get_tempo_service_names() -> TagValues:
    """Query Tempo for discovered service names in traces."""
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "tempo",
            "wget",
            "-qO-",
            "http://localhost:3200/api/search/tag/service.name/values",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )

    if result.returncode != 0:
        raise Exception(f"Tempo service names command failed: {result.stderr}")

    return TagValues.model_validate(json.loads(result.stdout))

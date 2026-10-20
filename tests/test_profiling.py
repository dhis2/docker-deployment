import pytest
import json
import os
import subprocess
from pydantic import BaseModel
from typing import Dict, List

from test_helpers import PROJECT_NAME, exec_in_service

CURL_IMAGE = "curlimages/curl:8.11.1"
PROXY_NETWORK = "proxy"
GLOWROOT_URL = f"http://{PROJECT_NAME}-app:4000"


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


@pytest.mark.order(17)
def test_glowroot_rejects_anonymous_access():
    """Verify Glowroot requires login for a container sharing the proxy network."""
    layout = json.loads(run_on_proxy_network(f"curl --silent {GLOWROOT_URL}/backend/layout"))
    assert layout["loginEnabled"], "Glowroot runs without login; anyone on the proxy network has admin access"

    status = run_on_proxy_network(
        f"curl --silent --output /dev/null --write-out '%{{http_code}}' {GLOWROOT_URL}/backend/admin/users"
    )
    assert status == "401", f"Anonymous request to Glowroot admin API answered {status}"


@pytest.mark.order(18)
def test_glowroot_admin_can_log_in():
    """Verify the Glowroot admin user logs in with GLOWROOT_ADMIN_PASSWORD."""
    login = json.dumps({"username": "admin", "password": os.environ["GLOWROOT_ADMIN_PASSWORD"]})
    status = run_on_proxy_network(
        "curl --silent --cookie-jar /tmp/cookies --header 'Content-Type: application/json'"
        f" --data \"$LOGIN\" {GLOWROOT_URL}/backend/login > /dev/null"
        " && curl --silent --cookie /tmp/cookies --output /dev/null --write-out '%{http_code}'"
        f" {GLOWROOT_URL}/backend/admin/users",
        env={"LOGIN": login},
    )
    assert status == "200", f"Glowroot admin API answered {status} after logging in"


class TagScope(BaseModel):
    name: str
    tags: List[str]


class SearchTagsV2Response(BaseModel):
    scopes: List[TagScope]


class TagValues(BaseModel):
    tagValues: List[str]


def get_tempo_ready() -> bool:
    """Check if Tempo is ready by querying the /ready endpoint."""
    result = exec_in_service(
        "tempo",
        ["wget", "-qO-", "--spider", "http://localhost:3200/ready"],
        project=PROJECT_NAME,
    )

    return result.returncode == 0


def get_tempo_tags() -> SearchTagsV2Response:
    """Query Tempo for available search tags grouped by scope."""
    result = exec_in_service(
        "tempo",
        ["wget", "-qO-", "http://localhost:3200/api/v2/search/tags"],
        project=PROJECT_NAME,
    )

    if result.returncode != 0:
        raise Exception(f"Tempo tags command failed: {result.stderr}")

    return SearchTagsV2Response.model_validate(json.loads(result.stdout))


def get_tempo_service_names() -> TagValues:
    """Query Tempo for discovered service names in traces."""
    result = exec_in_service(
        "tempo",
        ["wget", "-qO-", "http://localhost:3200/api/search/tag/service.name/values"],
        project=PROJECT_NAME,
    )

    if result.returncode != 0:
        raise Exception(f"Tempo service names command failed: {result.stderr}")

    return TagValues.model_validate(json.loads(result.stdout))


def run_on_proxy_network(script: str, env: Dict[str, str] = {}) -> str:
    """Run a shell script in a throwaway curl container on the proxy network."""
    env_args = [arg for name in env for arg in ("--env", name)]
    result = subprocess.run(
        ["docker", "run", "--rm", "--network", PROXY_NETWORK, *env_args, CURL_IMAGE, "sh", "-c", script],
        capture_output=True, text=True, timeout=60, env={**os.environ, **env},
    )
    if result.returncode != 0:
        raise Exception(f"Request on proxy network failed: {result.stderr}")
    return result.stdout.strip()

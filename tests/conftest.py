import os
from pathlib import Path

import pytest

from test_helpers import PROJECT_NAME, run_make_command


def _load_instance_env() -> None:
    """Load the instance .env into the environment so tests can read APP_HOSTNAME
    and admin credentials. Explicit environment values take precedence."""
    env_file = Path("instances") / PROJECT_NAME / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_load_instance_env()


@pytest.fixture(scope="session")
def browser_context_args(browser_context_args):
    return {
        **browser_context_args,
        "ignore_https_errors": True,
    }


@pytest.fixture(scope="session")
def backup_timestamp():
    """Get and cache the backup timestamp for the entire session."""
    return run_make_command("get-backup-timestamp", check=True).stdout.strip()


@pytest.fixture(scope="session", autouse=True)
def setup_test_environment(backup_timestamp: str):
    required_vars = ["APP_HOSTNAME", "DHIS2_ADMIN_USERNAME", "DHIS2_ADMIN_PASSWORD"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]

    if missing_vars:
        pytest.fail(f"Missing required environment variables: {missing_vars}")

    print(f"Test environment configured:")
    print(f"  APP_HOSTNAME: {os.getenv('APP_HOSTNAME')}")
    print(f"  DHIS2_ADMIN_USERNAME: {os.getenv('DHIS2_ADMIN_USERNAME')}")
    print(f"  DHIS2_ADMIN_PASSWORD: {'*' * len(os.getenv('DHIS2_ADMIN_PASSWORD', ''))}")
    print(f"  BACKUP_TIMESTAMP: {backup_timestamp}")


def pytest_configure(config):
    config.option.screenshot = "only-on-failure"

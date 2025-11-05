import os

import pytest

from test_helpers import run_make_command


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

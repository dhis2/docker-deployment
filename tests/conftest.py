import os
import pytest
from playwright.sync_api import BrowserContext
from test_helpers import get_backup_timestamp, cleanup_backups


@pytest.fixture(scope="session")
def browser_context_args(browser_context_args):
    return {
        **browser_context_args,
        "ignore_https_errors": True,
    }


@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    required_vars = ["APP_HOSTNAME", "DHIS2_ADMIN_USERNAME", "DHIS2_ADMIN_PASSWORD"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]

    if missing_vars:
        pytest.fail(f"Missing required environment variables: {missing_vars}")

    print(f"Test environment configured:")
    print(f"  APP_HOSTNAME: {os.getenv('APP_HOSTNAME')}")
    print(f"  DHIS2_ADMIN_USERNAME: {os.getenv('DHIS2_ADMIN_USERNAME')}")
    print(f"  DHIS2_ADMIN_PASSWORD: {'*' * len(os.getenv('DHIS2_ADMIN_PASSWORD', ''))}")

    pytest.backup_timestamp = get_backup_timestamp()
    print(f"  BACKUP_TIMESTAMP: {pytest.backup_timestamp}")


@pytest.fixture(scope="session", autouse=True)
def cleanup_after_tests():
    yield
    if hasattr(pytest, 'backup_timestamp'):
        cleanup_backups(pytest.backup_timestamp)


def pytest_configure(config):
    config.option.screenshot = "only-on-failure"

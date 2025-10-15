import pytest
from playwright.sync_api import Page, expect
from test_user_update_and_app_install import login_user
from test_helpers import (
    run_make_command, ensure_backups_directory, assert_backup_files_exist,
    wait_for_service_healthy
)


@pytest.mark.order(1)
def test_launch_environment():
    print("\n=== Step 1: Launch environment ===")

    run_make_command("launch COMPOSE_OPTS=-d")


@pytest.mark.order(3)
def test_create_backup():
    print("\n=== Step 3: Create backup ===")

    backup_timestamp = pytest.backup_timestamp

    ensure_backups_directory()
    run_make_command("backup", {"BACKUP_TIMESTAMP": backup_timestamp})
    assert_backup_files_exist(backup_timestamp)


@pytest.mark.order(4)
def test_clean_environment():
    print("\n=== Step 4: Clean environment ===")

    run_make_command("clean")


@pytest.mark.order(5)
def test_launch_fresh_environment():
    print("\n=== Step 5: Launch fresh environment ===")

    run_make_command("launch COMPOSE_OPTS=-d")


@pytest.mark.order(6)
def test_restore_from_backup():
    print("\n=== Step 6: Restore from backup ===")

    backup_timestamp = pytest.backup_timestamp

    restore_env = {
        "DB_RESTORE_FILE": f"{backup_timestamp}.pgc",
        "FILE_STORAGE_RESTORE_SOURCE_DIR": f"file-storage-{backup_timestamp}",
        "BACKUP_TIMESTAMP": backup_timestamp,
    }
    run_make_command("restore", restore_env)


@pytest.mark.order(7)
def test_verify_restored_data(page):
    print("\n=== Step 7: Verify restored data ===")

    wait_for_service_healthy("app")

    login_user(page)
    verify_restored_profile(page)
    verify_restored_app(page)


def verify_restored_profile(page: Page):
    print("Verifying restored user profile...")

    page.get_by_title("Profile menu").click()
    page.get_by_role("menuitem", name="My profile").click()
    page.wait_for_url("**/user-profile#/**")

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")
    expect(iframe.get_by_text('Edit user profile')).to_be_visible()

    expect(iframe.get_by_label("Job title")).to_have_value("developer")

    profile_picture = iframe.locator(".avatar-editor__image")
    expect(profile_picture).to_be_visible()


def verify_restored_app(page: Page):
    print("Verifying restored app installation...")

    page.get_by_title("Command palette").click()
    page.locator("#filter").fill("App Management")
    page.keyboard.press("Enter")

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")

    iframe.get_by_role("menuitem", name="Custom apps").click()
    expect(iframe.get_by_role("heading", name="All installed custom apps")).to_be_visible()
    expect(iframe.get_by_role("button", name="Android Settings")).to_be_visible()

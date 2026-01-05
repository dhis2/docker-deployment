import os
import pytest
from playwright.sync_api import Page, expect
from test_helpers import assert_no_services_unhealthy, assert_no_services_running, run_make_command, wait_for_service_healthy
from test_user_update_and_app_install import login_user


@pytest.mark.order(1)
def test_launch_environment():
    run_make_command("launch COMPOSE_OPTS=-d")

    assert_no_services_unhealthy()


@pytest.mark.order(4)
def test_create_backup(backup_timestamp: str):
    db_path = f"./backups/{backup_timestamp}.pgc"
    fs_path = f"./backups/file-storage-{backup_timestamp}"

    run_make_command("backup", {"BACKUP_TIMESTAMP": backup_timestamp})

    assert os.path.exists(db_path), f"Database backup not found: {db_path}"
    assert os.path.isdir(fs_path), f"File storage backup not found: {fs_path}"


@pytest.mark.order(5)
def test_clean_environment():
    run_make_command("clean")

    assert_no_services_running()


@pytest.mark.order(6)
def test_launch_fresh_environment():
    run_make_command("launch COMPOSE_OPTS=-d")

    assert_no_services_unhealthy()


@pytest.mark.order(7)
def test_restore_from_backup(page: Page, backup_timestamp: str):
    restore_env = {
        "DB_RESTORE_FILE": f"{backup_timestamp}.pgc",
        "FILE_STORAGE_RESTORE_SOURCE_DIR": f"file-storage-{backup_timestamp}",
        "BACKUP_TIMESTAMP": backup_timestamp,
    }
    run_make_command("restore", restore_env)

    wait_for_service_healthy("app")

    login_user(page)
    verify_restored_profile(page)
    verify_restored_app(page)


def verify_restored_profile(page: Page):
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
    page.get_by_title("Command palette").click()
    page.locator("#filter").fill("App Management")
    page.keyboard.press("Enter")

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")

    iframe.get_by_role("menuitem", name="Custom apps").click()
    expect(iframe.get_by_role("heading", name="All installed custom apps")).to_be_visible()
    expect(iframe.get_by_role("button", name="Android Settings")).to_be_visible()

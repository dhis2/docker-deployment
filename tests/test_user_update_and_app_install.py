import os
import time

import pytest
from playwright.sync_api import Page, Error as PlaywrightError, expect

URL = "https://" + os.getenv("APP_HOSTNAME")
USERNAME = os.getenv("DHIS2_ADMIN_USERNAME")
PASSWORD = os.getenv("DHIS2_ADMIN_PASSWORD")


def retry_on_network_change(action, attempts: int = 3, delay: int = 5):
    # On Linux, Docker bridge network creation triggers netlink address/link
    # notifications that cause Chromium to raise ERR_NETWORK_CHANGED on any
    # in-flight navigation, so retry the whole navigating action.
    for attempt in range(attempts):
        try:
            return action()
        except PlaywrightError as e:
            if "ERR_NETWORK_CHANGED" not in str(e) or attempt == attempts - 1:
                raise
            print(f"ERR_NETWORK_CHANGED on navigation, retrying ({attempt + 1}/{attempts})...")
            time.sleep(delay)


def login_user(page: Page):
    def do_login():
        page.goto(URL + "/login.html")
        page.get_by_role("textbox", name="Username").fill(USERNAME)
        page.get_by_role("textbox", name="Password").fill(PASSWORD)
        page.get_by_role("button", name="Log in").click()
        page.wait_for_url("**/dashboard#/**")
        expect(page).to_have_title("Dashboard | DHIS2")

    retry_on_network_change(do_login)


@pytest.mark.order(2)
def test_profile_update(page: Page):
    login_user(page)

    page.get_by_title("Profile menu").click()
    page.get_by_role("menuitem", name="My profile").click()
    page.wait_for_url("**/user-profile#/**")

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")
    expect(iframe.get_by_text('Edit user profile')).to_be_visible()

    expect(iframe.get_by_label("Job title")).to_have_value("")
    iframe.get_by_label("Job title").fill("developer")
    iframe.get_by_label("Introduction").click()

    retry_on_network_change(page.reload)
    expect(iframe.get_by_label("Job title")).to_have_value("developer")

    iframe.get_by_text("Select profile picture").click()
    iframe.locator('input[type="file"]').set_input_files("tests/fixtures/profile-image.png")

    profile_picture = iframe.locator(".avatar-editor__image")
    expect(profile_picture).to_be_visible()
    expect(profile_picture).to_have_js_property('complete', True)


@pytest.mark.order(3)
def test_app_install(page: Page):
    login_user(page)

    page.get_by_title("Command palette").click()
    page.get_by_text("App Management", exact=True).click()

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")

    iframe.get_by_role("menuitem", name="App Hub").click()

    iframe.get_by_role("button", name="Android Settings").click()
    iframe.get_by_role("button", name="Install").click()

    success = iframe.get_by_text("App installed successfully")
    error = iframe.get_by_text("Failed to install app")
    expect(success.or_(error)).to_be_visible(timeout=60000)
    expect(success).to_be_visible()

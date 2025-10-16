import os
import pytest
from playwright.sync_api import Page, expect

URL = "https://" + os.getenv("APP_HOSTNAME")
username = os.getenv("DHIS2_ADMIN_USERNAME")
password = os.getenv("DHIS2_ADMIN_PASSWORD")

def login_user(page: Page):
    dhis2_version = int(os.getenv("DHIS2_VERSION"))

    if dhis2_version >= 42:
        page.goto(URL + "/login.html")
    else:
        page.goto(URL + "/")

    page.get_by_role("textbox", name="Username").fill(username)
    page.get_by_role("textbox", name="Password").fill(password)
    page.get_by_role("button", name="Log in").click()
    page.wait_for_url("**/dashboard#/**")
    expect(page).to_have_title("Dashboard | DHIS2")

@pytest.mark.order(2)
def test_profile_update(page: Page):
    print("\n=== Update user profile ===")
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

    page.reload()
    expect(iframe.get_by_label("Job title")).to_have_value("developer")

    iframe.get_by_text("Select profile picture").click()
    iframe.locator('input[type="file"]').set_input_files("tests/fixtures/profile-image.png")

    profile_picture = iframe.locator(".avatar-editor__image")
    expect(profile_picture).to_be_visible()
    expect(profile_picture).to_have_js_property('complete', True)


@pytest.mark.order(2)
def test_app_install(page: Page):
    print("\n=== Install app ===")
    login_user(page)

    page.get_by_title("Command palette").click()
    page.locator("#filter").fill("App Management")
    page.keyboard.press("Enter")

    iframe = page.frame_locator("iframe")
    iframe.locator("body").wait_for(state="visible")

    iframe.get_by_role("menuitem", name="App Hub").click()

    iframe.get_by_role("button", name="Android Settings").click()
    iframe.get_by_role("button", name="Install").click()

    expect(iframe.get_by_text("App installed successfully")).to_be_visible(timeout=15000)

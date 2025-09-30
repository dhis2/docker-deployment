import os
import pytest
from playwright.sync_api import Page, expect

URL = "https://" + os.getenv("APP_HOSTNAME")
username = os.getenv("DHIS2_ADMIN_USERNAME")
password = os.getenv("DHIS2_ADMIN_PASSWORD")

def login_user(page: Page):
    page.goto(URL)

    page.wait_for_timeout(5000)

    page.screenshot(path="login-page.png")

    try:
        page.wait_for_selector('input[name="username"]', timeout=10000)
    except Exception as e:
        print(f"Failed to find username input: {e}")
        page.screenshot(path="login-page-no-username.png")

        with open("page-content.html", "w") as f:
            f.write(page.content())
        print("Page HTML saved to page-content.html")

        raise

    page.fill('input[name="username"]', username)
    page.fill('input[name="password"]', password)
    page.click('button[type="submit"]')
    page.wait_for_url("**/dashboard#/**")
    expect(page).to_have_title("Dashboard | DHIS2")

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

    page.reload()
    expect(iframe.get_by_label("Job title")).to_have_value("developer")

    iframe.get_by_text("Select profile picture").click()
    iframe.locator('input[type="file"]').set_input_files("tests/fixtures/profile-image.png")

    profile_picture = iframe.locator(".avatar-editor__image")
    expect(profile_picture).to_be_visible()
    expect(profile_picture).to_have_js_property('complete', True)

def test_app_install(page: Page):
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

import pytest
from playwright.sync_api import sync_playwright

URL = "https://dhis2-127-0-0-1.nip.io"

@pytest.fixture(scope="session")
def browser_context():
    with sync_playwright() as p:
        #browser = p.chromium.launch(headless=True)
        browser = p.chromium.launch()
        context = browser.new_context(ignore_https_errors=True)
        yield context
        browser.close()

#def test_example(browser_context):
#    page = browser_context.new_page()
#    page.goto(URL)
#    assert page.title() == "Login app | DHIS2"

def test_login(browser_context):
    page = browser_context.new_page()
    page.goto(URL)

    page.fill('input[name="username"]', "admin")
    page.fill('input[name="password"]', "district")

    page.click('button[type="submit"]')

    page.wait_for_url("**/dashboard#/**")

    assert "Dashboard" in page.title()

    page.get_by_title("Profile menu").click()
    page.screenshot(path="example0.png")
    page.get_by_role("menuitem", name="My profile").click()

    page.wait_for_url("**/user-profile#/**")
    #assert "User Profile" in page.title()

    page.screenshot(path="example1.png")
    page.wait_for_selector("input[id*='Firstname']", state="visible")
    page.screenshot(path="example2.png")
    assert page.get_by_text('Edit user profile').toBeVisible()


#page.get_by_text("Job title").click().fill("developer")
    page.locator("input[id*='Firstname']").click().fill("developer")
    #page.locator("input[id*='Jobtitle']").click().fill("developer")
    #page.locator("label:has-text('Job title') + input").fill("developer")



#id="undefined--Jobtitle-17437"
#    page.get_by_label("Job title").click().fill("Chief Geek")
#    page.get_by_label("Introduction").click().fill("...")


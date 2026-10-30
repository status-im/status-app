"""A dead Appium session fails the test at once and names itself.

When the Appium server behind a session restarts, every later command gets
``invalid session id``. The probe helpers must raise that error, not read it
as "element not there": otherwise navigation retries against a dead session
and the test reports a page failure such as "Failed to navigate to Messages".
"""

from unittest.mock import MagicMock

import pytest
from selenium.common.exceptions import InvalidSessionIdException, NoSuchElementException

from pages.app import App
from pages.base_page import BasePage
from support.element_state_checker import ElementStateChecker

pytestmark = [pytest.mark.gate, pytest.mark.component]

LOCATOR = ("xpath", "//*[@resource-id='anything']")


def _driver(error: Exception) -> MagicMock:
    driver = MagicMock()
    driver.find_element.side_effect = error
    driver.find_elements.side_effect = error
    driver.activate_app.side_effect = error
    return driver


def _dead() -> MagicMock:
    return _driver(InvalidSessionIdException("A session is either terminated or not started"))


def test_is_element_visible_raises_on_a_dead_session():
    with pytest.raises(InvalidSessionIdException):
        BasePage(_dead()).is_element_visible(LOCATOR, timeout=1)


def test_find_element_safe_raises_on_a_dead_session():
    with pytest.raises(InvalidSessionIdException):
        BasePage(_dead()).find_element_safe(LOCATOR, timeout=1)


def test_enabled_and_checked_probes_raise_on_a_dead_session():
    page = BasePage(_dead())
    with pytest.raises(InvalidSessionIdException):
        page._is_element_enabled(LOCATOR)
    with pytest.raises(InvalidSessionIdException):
        page._is_element_checked(LOCATOR)



def test_element_state_reads_raise_on_a_dead_session():
    element = MagicMock()
    element.parent.capabilities = {"platformName": "Android"}
    element.get_attribute.side_effect = InvalidSessionIdException("invalid session id")
    element.is_displayed.side_effect = InvalidSessionIdException("invalid session id")
    for check in (
        ElementStateChecker.is_enabled,
        ElementStateChecker.is_checked,
        ElementStateChecker.is_focused,
        ElementStateChecker.is_displayed,
        ElementStateChecker.get_text_content,
        ElementStateChecker.is_password_field,
        ElementStateChecker.is_field_empty,
    ):
        with pytest.raises(InvalidSessionIdException):
            check(element)


def test_missing_element_is_still_false_and_none():
    page = BasePage(_driver(NoSuchElementException()))
    assert page.is_element_visible(LOCATOR, timeout=0.1) is False
    assert page.find_element_safe(LOCATOR, timeout=0.1) is None
    assert page._is_element_enabled(LOCATOR, timeout=0.1) is False


def test_messages_nav_raises_on_the_first_command():
    driver = _dead()
    with pytest.raises(InvalidSessionIdException):
        assert App(driver).click_messages_button()
    assert driver.find_element.call_count == 1

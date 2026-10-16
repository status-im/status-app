"""The share picker: pick up to five chats, edit the text, send or cancel."""

from locators.share_locators import ShareLocators
from pages.base_page import BasePage


class SharePickerPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ShareLocators()

    def is_open(self, timeout: int | None = 15) -> bool:
        return self.is_element_visible(self.locators.PICKER, timeout=timeout)

    def wait_closed(self, timeout: int = 15) -> bool:
        return self.wait_for_invisibility(self.locators.PICKER, timeout=timeout)

    def tap_cancel(self) -> None:
        self.click(self.locators.CANCEL_BUTTON)

    def tap_send(self) -> None:
        self.click(self.locators.SEND_BUTTON)

    # None, not False, when the element is missing or the attribute is not a
    # plain "true" or "false": a check for "disabled" or "not ticked" must
    # not pass on an element whose state cannot be read.
    @staticmethod
    def _state(element, attribute: str) -> bool | None:
        if element is None:
            return None
        try:
            value = str(element.get_attribute(attribute)).lower()
        except Exception:
            return None
        return {"true": True, "false": False}.get(value)

    def is_send_enabled(self, timeout: int = 2) -> bool | None:
        element = self.find_element_safe(self.locators.SEND_BUTTON, timeout=timeout)
        return self._state(element, "enabled")

    def wait_for_send_enabled(self, enabled: bool, timeout: int = 10) -> bool:
        return self.wait_for_condition(
            lambda: self.is_send_enabled(timeout=1) is enabled, timeout=timeout, poll_interval=0.5,
        )

    def _list_area(self) -> tuple[int, int, int]:
        """Screen width, and the band between the tab bar and the composer."""
        size = self.driver.get_window_size()
        top, bottom = 0, size["height"]
        tab_bar = self.find_element_safe(self.locators.TAB_BAR, timeout=1)
        composer = self.find_element_safe(self.locators.COMPOSER, timeout=1)
        if tab_bar is not None:
            top = tab_bar.rect["y"] + tab_bar.rect["height"]
        if composer is not None:
            bottom = composer.rect["y"]
        return size["width"], top, bottom

    # Neighbouring tab pages are loaded too and list the same rows, and the
    # list keeps rows past its ends; the row to tap is the one whose centre
    # is on the current page, between the tab bar and the composer.
    def _on_screen_row(self, chat_id: str):
        try:
            width, top, bottom = self._list_area()
            candidates = self.driver.find_elements(*self.locators.destination_row(chat_id))
        except Exception:
            return None
        for element in candidates:
            try:
                rect = element.rect
            except Exception:
                continue
            centre_y = rect["y"] + rect["height"] / 2
            if (rect["width"] > 0 and 0 <= rect["x"] and rect["x"] + rect["width"] <= width
                    and top <= centre_y <= bottom):
                return element
        return None

    def wait_for_destination(self, chat_id: str, timeout: int = 60) -> bool:
        return self.wait_for_condition(
            lambda: self._on_screen_row(chat_id) is not None, timeout=timeout, poll_interval=2.0,
        )

    def select(self, chat_id: str) -> None:
        """Tap the chat's row, which toggles its tick."""
        element = self._on_screen_row(chat_id)
        if element is None:
            self.take_screenshot(f"share_row_missing_{chat_id[:12]}")
            self.dump_page_source(f"share_row_missing_{chat_id[:12]}")
            raise AssertionError(f"No share destination row for {chat_id[:16]}…")
        if not self.gestures.element_tap(element):
            raise AssertionError(f"Tap on the share row for {chat_id[:16]}… was not dispatched")

    def is_selected(self, chat_id: str) -> bool | None:
        element = self.find_element_safe(self.locators.destination_checkbox(chat_id), timeout=1)
        return self._state(element, "checked")

    def wait_for_selected(self, chat_id: str, selected: bool, timeout: int = 10) -> bool:
        return self.wait_for_condition(
            lambda: self.is_selected(chat_id) is selected, timeout=timeout, poll_interval=0.5,
        )

    def is_selectable(self, chat_id: str) -> bool | None:
        return self._state(self._on_screen_row(chat_id), "enabled")

    def wait_for_selectable(self, chat_id: str, selectable: bool, timeout: int = 10) -> bool:
        return self.wait_for_condition(
            lambda: self.is_selectable(chat_id) is selectable, timeout=timeout, poll_interval=0.5,
        )

    def browser_address(self, timeout: int = 15) -> str | None:
        return self._read_element_text(self.locators.BROWSER_ADDRESS_FIELD, timeout=timeout)

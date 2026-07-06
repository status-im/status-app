import re
import time
from typing import Optional

from selenium.common.exceptions import InvalidSessionIdException

from ..base_page import BasePage
from locators.wallet.send_locators import (
    SendSignModalLocators,
    SimpleSendModalLocators,
)


class SimpleSendModal(BasePage):
    """Page object for the send modal (recipient, token, amount, Review Send)."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SimpleSendModalLocators()

    def is_displayed(self, timeout: int = 15) -> bool:
        return self.is_element_visible(self.locators.RECIPIENT_INPUT, timeout=timeout)

    def _scroll_into_view(self, locator: tuple) -> bool:
        if self.is_element_visible(locator, timeout=2):
            return True
        return self.scroll_to_element(
            locator,
            container_locator=self.locators.SCROLL_VIEW,
            max_swipes=3,
            timeout=2,
        )

    def _log_send_resource_ids(self) -> None:
        """Log every on-screen resource-id containing 'Send' for triage."""
        try:
            source = self.driver.page_source or ""
            ids = sorted(set(re.findall(r'resource-id="([^"]*Send[^"]*)"', source)))
            self.logger.error(
                "Send-related resource-ids on screen: %s", ids or "none"
            )
        except Exception as exc:
            self.logger.debug("page-source diagnostic failed: %s", exc)

    def enter_recipient(self, address: str) -> bool:
        if not self._scroll_into_view(self.locators.RECIPIENT_INPUT):
            self.logger.error("Recipient input not visible in send modal")
            self._log_send_resource_ids()
            return False
        if self.wait_for_painted(self.locators.RECIPIENT_INPUT, timeout=10) is None:
            self.logger.error(
                "Recipient input present but never painted (zero bounds)"
            )
            self._log_send_resource_ids()
            return False
        if not self.qt_safe_input(self.locators.RECIPIENT_INPUT, address):
            # A resolved recipient replaces the input with a delegate chip, so
            # the input "vanishing" after typing is the success state.
            if self.find_element_safe(self.locators.RECIPIENT_FILLED, timeout=3):
                return True
            self._log_send_resource_ids()
            return False
        self.hide_keyboard()
        return True

    def ensure_eth_selected(self, timeout: int = 10) -> bool:
        """Select ETH in the token picker, or accept an existing selection.

        The picker list may already be open, the selector may already show
        ETH, or the selector may not be rendered at all (preselected asset).
        """
        selector = self.find_element_safe(self.locators.TOKEN_SELECTOR, timeout=3)
        if selector is None:
            if self.is_element_visible(self.locators.ETH_TOKEN_ITEM_PICKER, timeout=2):
                return self.try_click(
                    self.locators.ETH_TOKEN_ITEM_PICKER, timeout=timeout
                )
            self.logger.info("No token selector rendered — assuming preselected asset")
            return True

        current = ""
        for attr in ("content-desc", "text"):
            try:
                current += selector.get_attribute(attr) or ""
            except Exception:
                pass
        # Word-boundary match: "stETH"/"wETH" must not pass as ETH.
        if re.search(r"\bETH\b", current):
            self.logger.info("Token selector already shows ETH")
            return True

        # The picker list may already be open (stray tap, retried click)
        # while the selector button is still in the a11y tree — clicking the
        # selector then would toggle the list closed.
        if self.is_element_visible(self.locators.ETH_TOKEN_ITEM_PICKER, timeout=2):
            return self.try_click(self.locators.ETH_TOKEN_ITEM_PICKER, timeout=timeout)

        if not self.try_click(self.locators.TOKEN_SELECTOR, timeout=timeout):
            self.logger.error("Failed to open token selector")
            return False
        if not self.is_element_visible(
            self.locators.ETH_TOKEN_ITEM_PICKER, timeout=timeout
        ):
            self.logger.error("ETH item not visible in token picker")
            self.dump_page_source("token_picker_no_eth")
            self.take_screenshot("token_picker_no_eth")
            return False
        return self.try_click(self.locators.ETH_TOKEN_ITEM_PICKER, timeout=timeout)

    def enter_amount(self, amount: str) -> bool:
        if not self._scroll_into_view(self.locators.AMOUNT_INPUT):
            self.logger.error("Amount input not visible in send modal")
            self.dump_page_source("send_amount_missing")
            self.take_screenshot("send_amount_missing")
            return False
        element = self.wait_for_painted(self.locators.AMOUNT_INPUT, timeout=10)
        if element is None:
            self.logger.error("Amount input present but never painted (zero bounds)")
            self.dump_page_source("send_amount_unpainted")
            return False
        # Qt fields do not reliably expose their text for readback, so type
        # without verification; wait_for_route_ready is the success oracle.
        element.click()
        try:
            element.send_keys(amount)
        except Exception:
            self.driver.execute_script(
                "mobile: type", {"text": amount}
            )
        self.hide_keyboard()
        return True

    def wait_for_route_ready(self, timeout: int = 60) -> bool:
        """Wait until Review Send enables (route + fee estimation done)."""
        return self.wait_for_element_enabled(
            self.locators.REVIEW_SEND_BUTTON, timeout=timeout
        )

    def click_review_send(self, timeout: int = 10) -> Optional["SendSignModal"]:
        if not self.try_click(
            self.locators.REVIEW_SEND_BUTTON,
            fallback_locators=[self.locators.REVIEW_SEND_BUTTON_FALLBACK],
            timeout=timeout,
        ):
            self.logger.error("Failed to click Review Send")
            return None
        modal = SendSignModal(self.driver)
        if modal.is_displayed(timeout=30):
            return modal
        self.logger.error("Sign modal did not appear after Review Send")
        self.dump_page_source("sign_modal_missing")
        self.take_screenshot("sign_modal_missing")
        return None


class SendSignModal(BasePage):
    """Page object for the send/sign confirmation modal (SendSignModal.qml)."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SendSignModalLocators()

    def is_displayed(self, timeout: int = 30) -> bool:
        # Anchor on the modal chrome: the value boxes' a11y exposure is
        # intermittent, the footer sign button is not.
        return self.is_element_visible(self.locators.SIGN_BUTTON, timeout=timeout)

    def asset_value(self) -> Optional[str]:
        return self._read_value(self.locators.SEND_ASSET_VALUE_TID)

    def network_value(self) -> Optional[str]:
        return self._read_value(self.locators.NETWORK_VALUE_TID)

    def recipient_value(self) -> Optional[str]:
        """Read the To-box recipient text.

        Both the From and To boxes render a ``recipientDelegate``; document
        order is From first, so the recipient is the last match. min_matches=2
        refuses the read when only one delegate is reachable — taking a lone
        match risks reading the From box and passing vacuously.
        """
        return self._read_value(
            self.locators.RECIPIENT_DELEGATE_TID, last=True, min_matches=2
        )

    def _read_value(
        self, tid: str, last: bool = False, min_matches: int = 1, timeout: int = 30
    ) -> Optional[str]:
        """Read a value box's a11y text by test-id, polling until it appears.

        Value boxes below the modal's scroll fold keep zero bounds even after
        swiping, and UiAutomator2 prunes such nodes from element queries and
        page source unless allowInvisibleElements is on — enable it for the
        read and restore the session's prior setting after, so waits elsewhere
        keep their expected semantics.

        The value nodes also join the a11y tree a beat after the modal
        chrome renders, so a single read races the exposure — poll the full
        read until timeout and only then report the value absent. A dead
        session is not "value not there yet": InvalidSessionIdException
        propagates instead of burning the timeout.
        """
        prior_allow = False
        try:
            prior_allow = bool(
                (self.driver.get_settings() or {}).get("allowInvisibleElements", False)
            )
            self.driver.update_settings({"allowInvisibleElements": True})
        except InvalidSessionIdException:
            raise
        except Exception as exc:
            self.logger.debug("allowInvisibleElements toggle failed: %s", exc)
        try:
            deadline = time.monotonic() + timeout
            attempt = 0
            while True:
                attempt += 1
                value = self._value_from_page_source(tid, last, min_matches)
                if value:
                    if attempt > 1:
                        self.logger.info(
                            "Value %s appeared on read attempt %d", tid, attempt
                        )
                    return value
                if time.monotonic() >= deadline:
                    self.logger.error(
                        "Value %s absent after %d reads over %ds",
                        tid,
                        attempt,
                        timeout,
                    )
                    return None
                time.sleep(1)
        finally:
            try:
                self.driver.update_settings({"allowInvisibleElements": prior_allow})
            except Exception:
                pass

    def _value_from_page_source(
        self, tid: str, last: bool, min_matches: int
    ) -> Optional[str]:
        try:
            source = self.driver.page_source or ""
        except InvalidSessionIdException:
            raise
        except Exception as exc:
            self.logger.debug("page_source failed: %s", exc)
            return None
        # Test-ids surface either as "VALUE [tid:NAME]" in content-desc
        # (legacy) or as the resource-id leaf with the value in text or
        # content-desc (current convention). Appium page source tags are
        # class names (<android.widget.TextView ...>), and the resource-id
        # may be the bare tid or a dotted/slashed path ending in it.
        leaf = re.compile(r'resource-id="(?:[^"]*[./])?%s"' % re.escape(tid))
        values = []
        for node_match in re.finditer(r"<[A-Za-z][^>]*>", source):
            node = node_match.group(0)
            if f"[tid:{tid}]" not in node and not leaf.search(node):
                continue
            raw = ""
            for attr in ("content-desc", "text"):
                m = re.search(r'%s="([^"]*)"' % attr, node)
                if m and m.group(1):
                    raw = m.group(1)
                    break
            # Every matched node counts toward min_matches (mirroring the
            # element path); only the chosen node's text must be non-empty.
            values.append(raw.split(" [tid:")[0].strip())
        if len(values) < min_matches:
            return None
        value = values[-1] if last else values[0]
        return value or None

    def close_without_signing(self, timeout: int = 10) -> bool:
        """Dismiss the sign modal without touching the sign button.

        On phones the modal renders as a bottom sheet which hides Reject and
        shows the header close instead; the header close button objectName is
        shared with any dialog beneath, so tap the last (top-most) match.

        Dismissal is verified on the sign button — the chrome is_displayed
        anchored on, so it was provably visible before the close. The value
        boxes can be legitimately absent, which would make their
        invisibility pass vacuously on a failed close.
        """
        if self.is_element_visible(self.locators.REJECT_BUTTON, timeout=2):
            if not self.try_click(self.locators.REJECT_BUTTON, timeout=timeout):
                return False
        else:
            try:
                closers = self.driver.find_elements(
                    *self.locators.HEADER_CLOSE_BUTTON
                )
            except Exception as exc:
                self.logger.error("Header close lookup failed: %s", exc)
                return False
            if not closers:
                self.logger.error("No close button found on sign modal")
                return False
            if not self.gestures.element_tap(closers[-1]):
                return False
        return self.wait_for_invisibility(self.locators.SIGN_BUTTON, timeout=10)

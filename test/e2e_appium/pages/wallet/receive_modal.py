import base64
import re
from typing import Optional

from pages.base_page import BasePage
from locators.wallet.receive_modal_locators import ReceiveModalLocators


class ReceiveModal(BasePage):
    """Page object for the Receive Modal displaying QR code and wallet address."""

    _ETH_ADDRESS_RE = re.compile(r"0x[0-9a-fA-F]{40}")

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ReceiveModalLocators()

    @staticmethod
    def _extract_eth_address(value: str | None) -> Optional[str]:
        """Extract an Ethereum address (0x + 40 hex chars) from a string."""
        if not value:
            return None
        value = value.strip().replace("×", "x")
        match = ReceiveModal._ETH_ADDRESS_RE.search(value)
        return match.group(0) if match else None

    @staticmethod
    def _normalize_clipboard_text(value: str | None) -> Optional[str]:
        """Return clipboard text as a usable string.

        Some providers return base64 from `mobile: getClipboard`; handle both raw
        plaintext and base64.
        """
        if not value:
            return None
        raw = value.strip().replace("×", "x")
        if raw.startswith("0x"):
            return raw
        try:
            decoded = base64.b64decode(raw).decode("utf-8", errors="ignore").strip()
            decoded = decoded.replace("×", "x")
            return decoded if decoded.startswith("0x") else None
        except Exception:
            return None

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        """Check if the receive modal is visible."""
        return self.is_element_visible(self.locators.MODAL_CONTAINER, timeout=timeout)

    def wait_until_hidden(self, timeout: Optional[int] = 10) -> bool:
        """Wait for the receive modal to close."""
        return self.wait_for_invisibility(self.locators.MODAL_CONTAINER, timeout=timeout)

    def is_qr_code_visible(self, timeout: Optional[int] = 10) -> bool:
        """Verify QR code element is displayed via accessibility name."""
        return self.is_element_visible(self.locators.QR_CODE_IMAGE, timeout=timeout)

    def get_address(self, timeout: Optional[int] = 10) -> Optional[str]:
        """Extract the displayed wallet address text.
        
        The address is exposed via Accessible.name which maps to content-desc on Android.
        Note: The font may render 'x' as multiplication sign '×' (U+00D7).
        """
        element = self.find_element_safe(self.locators.ADDRESS_TEXT, timeout=timeout)
        if element:
            raw = element.get_attribute("content-desc") or element.text
            address = self._extract_eth_address(raw)
            if address:
                return address
        self.logger.warning("Address text element not found in accessibility tree")
        return None

    def copy_address(self, timeout: Optional[int] = 10) -> Optional[str]:
        """Click the copy button and return the address from clipboard.
        
        Returns:
            The wallet address from clipboard, or None if copy failed.
        """
        expected_address = self.get_address(timeout=2)

        clipboard_reset = False
        before_clipboard: Optional[str] = None
        try:
            before_clipboard = (self.driver.get_clipboard_text() or "").strip()
        except Exception:
            before_clipboard = None

        try:
            self.driver.set_clipboard_text("")
            clipboard_reset = True
            before_clipboard = ""
        except Exception as exc:
            self.logger.debug("Unable to reset clipboard before copy: %s", exc)

        if not self.safe_click(self.locators.COPY_BUTTON, timeout=timeout):
            self.logger.error("Failed to click copy address button")
            return None
        
        clipboard_result = [None]
        last_seen_clipboard: dict[str, Optional[str]] = {"value": None}
        
        def check_clipboard():
            try:
                raw_text = self.driver.get_clipboard_text()
                text = self._normalize_clipboard_text(raw_text)
                if not text:
                    return False
                last_seen_clipboard["value"] = text

                # If we can read the displayed address, require clipboard to match it.
                if expected_address and text.lower() != expected_address.lower():
                    return False

                # Otherwise, require clipboard to change when we couldn't reset it.
                if not clipboard_reset and before_clipboard and text == before_clipboard:
                    return False

                clipboard_result[0] = text
                return True
            except Exception:
                pass
            return False
        
        if self.wait_for_condition(check_clipboard, timeout=3, poll_interval=0.1):
            return clipboard_result[0]
        
        self.logger.error(
            "Clipboard did not contain a valid address after copy (expected=%s, last=%s)",
            expected_address,
            last_seen_clipboard["value"],
        )
        return None

    def close(self) -> bool:
        """Dismiss the receive modal by pressing back."""
        try:
            self.driver.press_keycode(4)  # Android BACK key
            return self.wait_until_hidden(timeout=5)
        except Exception as e:
            self.logger.error(f"Failed to close receive modal: {e}")
            return False

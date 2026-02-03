from typing import Optional

from pages.base_page import BasePage
from locators.wallet.receive_modal_locators import ReceiveModalLocators


class ReceiveModal(BasePage):
    """Page object for the Receive Modal displaying QR code and wallet address."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ReceiveModalLocators()

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
            # Address is in content-desc (from Accessible.name)
            address = element.get_attribute("content-desc") or element.text
            if address:
                address = address.strip()
                # Normalize multiplication sign to 'x' if present
                address = address.replace("×", "x")
                if address.startswith("0x"):
                    return address
        self.logger.warning("Address text element not found in accessibility tree")
        return None

    def copy_address(self, timeout: Optional[int] = 10) -> Optional[str]:
        """Click the copy button and return the address from clipboard.
        
        Returns:
            The wallet address from clipboard, or None if copy failed.
        """
        if not self.safe_click(self.locators.COPY_BUTTON, timeout=timeout):
            self.logger.error("Failed to click copy address button")
            return None
        
        try:
            # Small delay to ensure clipboard is updated
            import time
            time.sleep(0.3)
            clipboard_text = self.driver.get_clipboard_text()
            if clipboard_text:
                return clipboard_text.strip()
        except Exception as e:
            self.logger.error(f"Failed to get clipboard content: {e}")
        return None

    def close(self) -> bool:
        """Dismiss the receive modal by pressing back."""
        try:
            self.driver.press_keycode(4)  # Android BACK key
            return self.wait_until_hidden(timeout=5)
        except Exception as e:
            self.logger.error(f"Failed to close receive modal: {e}")
            return False

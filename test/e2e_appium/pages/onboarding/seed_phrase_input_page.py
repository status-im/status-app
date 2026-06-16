import time
from typing import List, Union

from ..base_page import BasePage
from locators.base_locators import BaseLocators
from locators.onboarding.seed_phrase_input_locators import SeedPhraseInputLocators


class SeedPhraseInputPage(BasePage):

    def __init__(self, driver, flow_type: str = "create"):
        super().__init__(driver)
        self.locators = SeedPhraseInputLocators()

        if flow_type == "login":
            self.IDENTITY_LOCATOR = self.locators.SEED_PHRASE_INPUT_SCREEN_LOGIN
        else:
            self.IDENTITY_LOCATOR = self.locators.SEED_PHRASE_INPUT_SCREEN_CREATE

    def paste_seed_phrase_via_clipboard(self, seed_phrase: str) -> bool:
        """Enter the seed phrase by typing each word into its own field.

        Method name is legacy — we no longer paste. ``EnterSeedPhrase.qml``'s
        paste-split handler fires on ``Keys.onPressed StandardKey.Paste``
        (Ctrl+V) which the Android paste chip does not emit, so per-field
        typing is the only path that populates all N fields. Step 1 selects
        the length tab so the matching field count renders.
        """
        try:
            words = seed_phrase.strip().split()
            if not words:
                self.logger.error("Empty seed phrase")
                return False

            length = len(words)
            if length not in (12, 18, 24):
                self.logger.error("Unsupported seed length %d (must be 12/18/24)", length)
                return False

            # Step 1: select the length tab so EnterSeedPhrase renders N fields.
            self.logger.info("Selecting %d-word length", length)
            length_button = BaseLocators.tid(f"{length}SeedButton")
            if not self.safe_click(length_button, timeout=5):
                self.logger.warning(
                    "Failed to click %dSeedButton — proceeding (default may be %d already)",
                    length, length,
                )
            time.sleep(0.3)  # let the field-count repeater settle

            self.logger.info("Entering seed phrase across %d fields", length)
            size = self.driver.get_window_size()
            cx = int(size["width"] * 0.5)
            for idx, word in enumerate(words, start=1):
                field_locator = self.locators.get_seed_word_input_field(idx)
                # The raised keyboard can push the next field off-screen; Qt then
                # drops it from the a11y tree entirely. Hide keyboard + swipe it back.
                if not self.find_element_safe(field_locator, timeout=2):
                    try:
                        self.hide_keyboard()
                    except Exception:
                        pass
                    for _ in range(4):
                        if self.find_element_safe(field_locator, timeout=1):
                            break
                        self.driver.swipe(cx, int(size["height"] * 0.8),
                                          cx, int(size["height"] * 0.5), 400)
                        time.sleep(0.3)
                if not self.qt_safe_input(field_locator, word, verify=False):
                    self.logger.error("Failed to enter word %d", idx)
                    return False
                self.logger.debug("Entered word %d/%d: %s", idx, length, word)

            try:
                self.hide_keyboard()
                time.sleep(0.3)
            except Exception:
                pass

            self.logger.info("✅ Seed phrase entry completed (%d words)", length)
            return True

        except Exception as e:
            self.logger.error(f"Seed phrase entry failed: {e}")
            return False

    def click_continue(self) -> bool:
        self.logger.info("Clicking Continue button")

        # btnContinue sits at the bottom of SeedphrasePage's StatusScrollView
        # and is clipped at the scroll boundary until scrolled to — it is in the
        # a11y tree but not painted, so taps miss. scroll_to_element early-returns
        # (Qt marks the clipped button "visible"), so swipe to the bottom
        # explicitly to render it, then tap.
        size = self.driver.get_window_size()
        cx = int(size["width"] * 0.5)
        for _ in range(5):
            self.driver.swipe(
                cx, int(size["height"] * 0.85), cx, int(size["height"] * 0.35), 400
            )
            time.sleep(0.3)

        button = self.find_element_safe(self.locators.CONTINUE_BUTTON, timeout=5)
        if not button:
            self.logger.error("❌ Failed to find Continue button")
            return False

        rect = button.rect
        if self.tap_coordinate_relative(button, rect["width"] // 2, rect["height"] // 2):
            self.logger.info("✅ Continue button tapped")
            return True

        self.logger.error("❌ Failed to click Continue button")
        return False

    def is_continue_button_enabled(self) -> bool:
        element = self.find_element_safe(self.locators.CONTINUE_BUTTON)
        if element and element.is_displayed():
            is_enabled = element.is_enabled()
            self.logger.debug(f"Continue button enabled: {is_enabled}")
            return is_enabled

        self.logger.warning("Continue button not found")
        return False

    def import_seed_phrase(self, seed_phrase: Union[str, List[str]]) -> bool:
        """Complete seed phrase import flow."""
        self.logger.info("Starting seed phrase import process")

        if isinstance(seed_phrase, list):
            seed_phrase = " ".join(seed_phrase)

        if not self.paste_seed_phrase_via_clipboard(seed_phrase):
            return False

        try:
            if self.hide_keyboard():
                time.sleep(0.5)
        except Exception:
            pass

        return self.click_continue()

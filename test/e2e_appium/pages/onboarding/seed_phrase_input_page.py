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
            for idx, word in enumerate(words, start=1):
                field_locator = self.locators.get_seed_word_input_field(idx)
                if not self.ensure_element_visible(field_locator):
                    self.logger.warning("Field %d not visible; trying anyway", idx)
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

        # btnContinue sits BELOW the seed-input column inside SeedphrasePage's
        # StatusScrollView. With 12+ fields above it the button is offscreen
        # and Qt does not surface offscreen elements via accessibility — so a
        # plain xpath search returns nothing. Scroll it into view first.
        if not self.is_element_visible(self.locators.CONTINUE_BUTTON, timeout=2):
            self.scroll_to_element(
                self.locators.CONTINUE_BUTTON, max_swipes=4, timeout=2,
            )

        if self.safe_click(self.locators.CONTINUE_BUTTON):
            self.logger.info("✅ Continue button clicked successfully")
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

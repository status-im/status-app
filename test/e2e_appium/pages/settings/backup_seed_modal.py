from typing import Optional, Dict
from selenium.webdriver.support import expected_conditions as EC
import re

from ..base_page import BasePage
from locators.settings.backup_seed_locators import BackupSeedLocators
from support.element_state_checker import ElementStateChecker


class BackupSeedModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = BackupSeedLocators()

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.MODAL_ROOT, timeout=timeout)

    def click_next(self) -> bool:
        return self.try_click(self.locators.NEXT_BUTTON)

    def reveal_seed_phrase(self) -> bool:
        return self.try_click(self.locators.REVEAL_BUTTON)

    def get_seed_words_map(self) -> Dict[int, str]:
        mapping: Dict[int, str] = {}
        try:
            nodes = self.driver.find_elements(*self.locators.SEED_WORD_TEXT_NODES)
        except Exception:
            nodes = []
        for node in nodes:
            try:
                desc = node.get_attribute("content-desc") or ""
                # Expected format: "<word> [tid:seedWordText_N]"
                m = re.match(r"^(?P<word>.+?)\s+\[tid:seedWordText_(?P<idx>\d+)\]$", desc)
                if m:
                    idx = int(m.group("idx"))
                    word = (m.group("word") or "").strip()
                    if word:
                        mapping[idx] = word
            except Exception:
                continue
        return mapping

    def fill_confirmation_words(self, index_to_word: Dict[int, str]) -> bool:
        try:
            inputs = self.driver.find_elements(*self.locators.CONFIRM_INPUTS_ANY)
        except Exception:
            inputs = []
        if len(inputs) < 4:
            return False

        def _pos_key(el):
            try:
                r = el.rect or {}
                return (int(r.get("y", 0)), int(r.get("x", 0)))
            except Exception:
                return (0, 0)

        inputs = sorted(inputs, key=_pos_key)
        for el in inputs[:4]:
            idx = self._parse_input_index(el)
            if idx is None or idx not in index_to_word:
                try:
                    self.logger.error(
                        f"No word for requested index {idx}; available keys: {sorted(index_to_word.keys())}"
                    )
                except Exception:
                    pass
                return False
            word = index_to_word[idx]
            try:
                self.logger.info(f"Entering confirm word index {idx}: '{word}'")
            except Exception:
                pass
            try:
                self.gestures.element_tap(el)
                self._wait_for_qt_field_ready(el)
                self.driver.execute_script("mobile: type", {"text": word})
            except Exception:
                return False
        try:
            self.hide_keyboard()
        except Exception:
            pass
        return True

    def click_continue(self) -> bool:
        return self.try_click(self.locators.CONTINUE_BUTTON)

    def click_done(self) -> bool:
        return self.try_click(self.locators.DONE_BUTTON)

    def set_remove_checkbox(self, checked: bool = True) -> bool:
        el = self.find_element_safe(self.locators.DELETE_CHECKBOX, timeout=3)
        if not el:
            return False
        current = ElementStateChecker.is_checked(el)
        if current == checked:
            return True
        return self.try_click(self.locators.DELETE_CHECKBOX)

    def wait_until_closed(self, timeout: Optional[int] = 10) -> bool:
        try:
            wait = self._create_wait(timeout, "element_wait")
            return wait.until(
                EC.invisibility_of_element_located(self.locators.MODAL_ROOT)
            )
        except Exception:
            return False

    def _parse_input_index(self, element) -> Optional[int]:
        try:
            rid = element.get_attribute("resource-id") or ""
            m = re.search(r"seedInput_(\d+)", rid)
            if m:
                return (
                    int(m.group(1)) + 1
                )  # seedInput_<n> appears 0-based → convert to 1-based
            desc = element.get_attribute("content-desc") or ""
            m2 = re.search(r"\[tid:seedInput_(\d+)\]", desc)
            if m2:
                return int(m2.group(1)) + 1
            name = element.get_attribute("name") or ""
            m3 = re.search(r"seedInput_(\d+)", name)
            if m3:
                return int(m3.group(1)) + 1
        except Exception:
            return None
        return None

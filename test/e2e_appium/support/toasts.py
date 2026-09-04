from typing import List

from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from config.logging_config import get_logger


class Toasts:

    def __init__(self, driver):
        self.driver = driver
        self.logger = get_logger("toasts")

    def wait_for_messages(self, timeout: int = 5) -> List[str]:
        messages: List[str] = []
        wait = WebDriverWait(self.driver, timeout)

        # Strategy 1: Native Android Toast widget
        try:
            toast = wait.until(
                EC.presence_of_element_located(
                    (AppiumBy.XPATH, "//android.widget.Toast")
                )
            )
            text = toast.get_attribute("text") or ""
            if text:
                messages.append(text)
        except Exception:
            pass

        # Strategy 2: Elements containing success/removed/added
        xpath_patterns = [
            "//*[contains(@text, 'success')]",
            "//*[contains(@text, 'removed')]",
            "//*[contains(@text, 'added')]",
            "//*[contains(@content-desc, 'success')]",
        ]
        for xp in xpath_patterns:
            try:
                els = self.driver.find_elements(AppiumBy.XPATH, xp)
                for el in els:
                    txt = (
                        el.get_attribute("text")
                        or el.get_attribute("content-desc")
                        or ""
                    )
                    if txt and txt not in messages:
                        messages.append(txt)
            except Exception:
                continue

        return messages

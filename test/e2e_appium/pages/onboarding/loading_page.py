"""
Loading Page for Status Desktop E2E Testing

Page object for splash during onboarding.
"""

from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException,
    WebDriverException,
    NoSuchWindowException,
    InvalidSessionIdException,
)

from ..base_page import BasePage
from locators.onboarding.loading_screen_locators import LoadingScreenLocators
from locators.wallet.accounts_locators import WalletAccountsLocators


class SplashScreen(BasePage):
    """Page object for the Loading/Splash screen during onboarding"""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = LoadingScreenLocators()
        self.IDENTITY_LOCATOR = self.locators.SPLASH_SCREEN_PARTIAL

    def is_progress_bar_visible(self) -> bool:
        return self.is_element_visible(self.locators.PROGRESS_BAR)

    def wait_for_loading_completion(self, timeout: int = 60) -> bool:
        """Wait for loading to complete using explicit invisibility wait"""
        self.logger.info(f"Waiting for loading completion (timeout: {timeout}s)")
        try:
            wait = WebDriverWait(self.driver, timeout)
            wait.until(
                EC.invisibility_of_element_located(self.locators.SPLASH_SCREEN_PARTIAL)
            )
            self.logger.info("Loading completed - screen disappeared")
            return True
        except (NoSuchWindowException, InvalidSessionIdException) as e:
            self.logger.error(
                f"WebDriver session ended during loading wait: {type(e).__name__}: {e}"
            )
            return False
        except WebDriverException as e:
            self.logger.warning(
                f"WebDriver error during loading wait: {type(e).__name__}: {e}"
            )
            try:
                _ = self.driver.current_url
            except (WebDriverException, InvalidSessionIdException, NoSuchWindowException):
                self.logger.error("WebDriver session appears to be dead")
                return False
            return False
        except TimeoutException:
            self.logger.warning(
                f"Loading did not complete within {timeout} seconds; checking wallet state"
            )
            try:
                if self.is_element_visible(WalletAccountsLocators.ADD_ACCOUNT_BUTTON, timeout=5):
                    self.logger.info(
                        "Wallet add account button visible despite splash locator; continuing"
                    )
                    return True
            except Exception:
                pass
            return False
        except Exception:
            self.logger.warning(
                "Unexpected error while waiting for loading completion", exc_info=True
            )
            return False

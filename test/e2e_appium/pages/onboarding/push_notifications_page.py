from ..base_page import BasePage
from locators.onboarding.push_notifications_locators import PushNotificationsLocators
from utils.exceptions import ElementInteractionError


class PushNotificationsPage(BasePage):
    """Page object for the 'Enable push notifications' dialog.

    This dialog may appear after onboarding completes and the wallet
    landing screen loads.  It blocks interaction with all underlying
    UI until dismissed.
    """

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = PushNotificationsLocators()
        self.IDENTITY_LOCATOR = self.locators.MAYBE_LATER_BUTTON

    def select_maybe_later(self) -> bool:
        """Dismiss the dialog by tapping 'Maybe later'."""
        try:
            self.safe_click(self.locators.MAYBE_LATER_BUTTON)
        except ElementInteractionError:
            self.logger.error(
                "Failed to tap 'Maybe later' on push notifications dialog",
                exc_info=True,
            )
            return False

        return self.wait_for_invisibility(self.IDENTITY_LOCATOR)

    def dismiss_if_present(self, timeout: int = 3) -> bool:
        """Dismiss the push notifications dialog if it is visible.

        Safe to call at any point (e.g. after an app restart) — returns
        True if the dialog was not present or was successfully dismissed.
        """
        if not self.is_element_visible(self.locators.MAYBE_LATER_BUTTON, timeout=timeout):
            return True
        self.logger.info("Push notifications dialog detected post-restart, dismissing")
        return self.select_maybe_later()

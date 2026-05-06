from ..base_locators import BaseLocators


class PushNotificationsLocators(BaseLocators):
    """Locators for the 'Enable push notifications' dialog shown post-onboarding."""

    DIALOG = BaseLocators.xpath(
        "//*[contains(@resource-id,'EnablePushNotificationsPopup')]"
    )
    MAYBE_LATER_BUTTON = BaseLocators.tid("btnPushNotificationsLater")
    CONTINUE_BUTTON = BaseLocators.tid("btnPushNotificationsPrimary")
    CLOSE_BUTTON = BaseLocators.tid("headerActionsCloseButton")

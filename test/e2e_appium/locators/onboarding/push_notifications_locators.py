from ..base_locators import BaseLocators


class PushNotificationsLocators(BaseLocators):
    """Locators for the 'Enable push notifications' dialog shown post-onboarding."""

    DIALOG = BaseLocators.xpath(
        "//*[contains(@resource-id,'EnablePushNotificationsPopup')]"
    )
    MAYBE_LATER_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, 'tid:btnPushNotificationsLater') "
        "or contains(@name, 'btnPushNotificationsLater')]"
    )
    CONTINUE_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, 'tid:btnPushNotificationsPrimary') "
        "or contains(@name, 'btnPushNotificationsPrimary')]"
    )
    CLOSE_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, 'tid:headerActionsCloseButton') "
        "or contains(@name, 'headerActionsCloseButton')]"
    )

from ..base_locators import BaseLocators


class PushNotificationsLocators(BaseLocators):
    """Locators for the 'Enable push notifications' dialog shown post-onboarding."""

    DIALOG_ID = "EnablePushNotificationsPopup"
    DIALOG = BaseLocators.object_name_contains(DIALOG_ID)
    MAYBE_LATER_BUTTON = BaseLocators.tid("btnPushNotificationsLater")
    CONTINUE_BUTTON = BaseLocators.tid("btnPushNotificationsPrimary")
    CLOSE_BUTTON = BaseLocators.tid("headerActionsCloseButton")

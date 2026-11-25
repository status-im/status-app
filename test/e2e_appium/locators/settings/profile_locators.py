from ..base_locators import BaseLocators


class ProfileSettingsLocators(BaseLocators):
    SHARE_PROFILE_BUTTON = BaseLocators.tid("shareProfileButton")
    PROFILE_TAB_IDENTITY = BaseLocators.tid("identityTabButton")
    PROFILE_LINK_INPUT = BaseLocators.object_name_contains("profileLinkInput")
    SHARE_PROFILE_DIALOG = BaseLocators.object_name_contains("ShareProfileDialog")



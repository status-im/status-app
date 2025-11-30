from ..base_locators import BaseLocators


class ProfileSettingsLocators(BaseLocators):
    SHARE_PROFILE_BUTTON = BaseLocators.content_desc_contains("[tid:shareProfileButton]")
    PROFILE_TAB_IDENTITY = BaseLocators.content_desc_contains("[tid:identityTabButton]")
    PROFILE_LINK_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'profileLinkInput')]"
    )
    SHARE_PROFILE_DIALOG = BaseLocators.xpath(
        "//*[contains(@resource-id,'ShareProfileDialog')]"
    )



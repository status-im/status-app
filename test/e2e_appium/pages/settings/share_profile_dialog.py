
from locators.settings.profile_locators import ProfileSettingsLocators

from ..base_page import BasePage


class ShareProfileDialog(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ProfileSettingsLocators()

    def is_displayed(self, timeout: int | None = 6) -> bool:
        return self.is_element_visible(self.locators.SHARE_PROFILE_DIALOG, timeout=timeout)

    def get_profile_link(self) -> str | None:
        """Extract the profile link from the ShareProfileDialog input.

        The link lives in content-desc as:
          ``https://status.app/u/#zQ3... [tid:profileLinkInput]``
        We strip the ``[tid:...]`` suffix and any Android ``"null"`` strings.
        """
        element = self.find_element_safe(self.locators.PROFILE_LINK_INPUT)
        if not element:
            return None

        # Try content-desc first (most reliable on Android/Qt)
        for attr in ("content-desc", "text", "hint"):
            raw = element.get_attribute(attr)
            if not raw or raw == "null":
                continue
            # Strip the [tid:...] suffix that Accessible.name includes
            value = raw.split(" [tid:")[0].strip()
            if value.startswith("https://status.app/"):
                return value
        return None



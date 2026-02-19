from utils.platform import is_ios as _is_ios_driver


def _element_is_ios(element) -> bool:
    """Detect whether an element belongs to an iOS session.

    Appium ``WebElement`` objects expose a ``parent`` attribute that
    references the driver, which lets us read ``platformName`` without
    requiring callers to pass extra context.
    """
    driver = getattr(element, "parent", None)
    if driver is None:
        return False
    return _is_ios_driver(driver)


class ElementStateChecker:
    """Static utility methods for element state checks.

    Methods are platform-aware: they detect iOS vs Android via the
    element's parent driver and read the appropriate attributes.
    """

    @staticmethod
    def is_enabled(element) -> bool:
        try:
            value = element.get_attribute("enabled")
            return value is not None and str(value).lower() == "true"
        except Exception:
            return False

    @staticmethod
    def is_checked(element) -> bool:
        try:
            return str(element.get_attribute("checked")).lower() == "true"
        except Exception:
            return False

    @staticmethod
    def is_focused(element) -> bool:
        """Check whether the element has input focus.

        On iOS the ``focused`` attribute does not exist; we return
        ``False`` as a safe default so callers can proceed.
        """
        if _element_is_ios(element):
            return False
        try:
            return str(element.get_attribute("focused")).lower() == "true"
        except Exception:
            return False

    @staticmethod
    def is_displayed(element) -> bool:
        try:
            return element.is_displayed()
        except Exception:
            return False

    @staticmethod
    def get_text_content(element) -> str:
        """Return the visible text from an element.

        Android: tries ``text``, ``content-desc``, ``name``.
        iOS:     tries ``value``, ``label``, ``name``.
        """
        try:
            if _element_is_ios(element):
                attrs = ("value", "label", "name")
            else:
                attrs = ("text", "content-desc", "name")

            for attr in attrs:
                value = element.get_attribute(attr)
                if value and value.strip():
                    return value.strip()
            return ""
        except Exception:
            return ""

    @staticmethod
    def is_password_field(element) -> bool:
        """Detect password input fields.

        Android: checks ``resource-id`` and ``content-desc`` for
        "password" hints.
        iOS: checks the element ``type`` for
        ``XCUIElementTypeSecureTextField``, and falls back to
        ``name`` / ``label`` attribute inspection.
        """
        try:
            if _element_is_ios(element):
                element_type = element.get_attribute("type") or ""
                if "SecureTextField" in element_type:
                    return True
                name = element.get_attribute("name") or ""
                label = element.get_attribute("label") or ""
                return (
                    "password" in name.lower()
                    or "password" in label.lower()
                )

            resource_id = element.get_attribute("resource-id") or ""
            content_desc = element.get_attribute("content-desc") or ""
            return (
                "password" in resource_id.lower()
                or content_desc.lower() == "type password"
            )
        except Exception:
            return False

    @staticmethod
    def is_field_empty(element) -> bool:
        """Return ``True`` when the element contains no visible text.

        Checks platform-appropriate attributes.
        """
        try:
            if _element_is_ios(element):
                attrs = ("value", "label", "name")
            else:
                attrs = ("text", "content-desc", "name", "hint")

            for attr in attrs:
                val = element.get_attribute(attr)
                if val and len(val.strip()) > 0:
                    return False
            return True
        except Exception:
            return True

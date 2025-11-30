


class ElementStateChecker:
    """Static utility methods for element state checks."""

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
        try:
            # Try different attributes in order of preference
            for attr in ("text", "content-desc", "name"):
                value = element.get_attribute(attr)
                if value and value.strip():
                    return value.strip()
            return ""
        except Exception:
            return ""

    @staticmethod
    def is_password_field(element) -> bool:
        try:
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
        try:
            for attr in ("text", "content-desc", "name", "hint"):
                val = element.get_attribute(attr)
                if val and len(val.strip()) > 0:
                    return False
            return True
        except Exception:
            return True

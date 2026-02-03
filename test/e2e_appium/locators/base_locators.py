from appium.webdriver.common.appiumby import AppiumBy


def xpath_string(value: str) -> str:
    """Escape a string for safe use in XPath 1.0 expressions.
    
    XPath 1.0 does not support backslash escaping. Strings must be quoted
    with single or double quotes. If a string contains both quote types,
    it must be constructed using concat().
    
    Args:
        value: The string to escape.
        
    Returns:
        A string safe for embedding in XPath (includes outer quotes or concat()).
        
    Output examples (as XPath literals):
        "hello"           -> "hello"
        "don't"           -> "don't"           (single quote inside double quotes)
        'he said "hi"'    -> 'he said "hi"'    (double quote inside single quotes)
        "it's a \"test\"" -> concat("it's a ", '"', "test", '"')
    """
    if '"' not in value:
        return f'"{value}"'
    if "'" not in value:
        return f"'{value}'"
    
    # Contains both quote types - use concat()
    # Split on double quotes and insert literal '"' (single-quoted) between parts
    parts = value.split('"')
    xpath_parts = []
    for i, part in enumerate(parts):
        if part:
            xpath_parts.append(f'"{part}"')
        if i < len(parts) - 1:
            xpath_parts.append("'\"'")  # XPath literal: double quote in single quotes
    return f"concat({', '.join(xpath_parts)})"


class BaseLocators:
    BY_ACCESSIBILITY_ID = AppiumBy.ACCESSIBILITY_ID
    BY_ID = AppiumBy.ID
    BY_XPATH = AppiumBy.XPATH
    BY_CLASS_NAME = AppiumBy.CLASS_NAME
    BY_ANDROID_UIAUTOMATOR = AppiumBy.ANDROID_UIAUTOMATOR

    @staticmethod
    def accessibility_id(value: str) -> tuple:
        return (BaseLocators.BY_ACCESSIBILITY_ID, value)

    @staticmethod
    def id(value: str) -> tuple:
        return (BaseLocators.BY_ID, value)

    @staticmethod
    def xpath(value: str) -> tuple:
        return (BaseLocators.BY_XPATH, value)

    @staticmethod
    def class_name(value: str) -> tuple:
        return (BaseLocators.BY_CLASS_NAME, value)

    @staticmethod
    def android_uiautomator(value: str) -> tuple:
        return (BaseLocators.BY_ANDROID_UIAUTOMATOR, value)

    @staticmethod
    def resource_id_contains(value: str) -> tuple:
        return (
            BaseLocators.BY_XPATH,
            f"//*[contains(@resource-id, '{value}')]",
        )

    @staticmethod
    def text_contains(text: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//*[contains(@text, '{text}')]")

    @staticmethod
    def text_exact(text: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//*[@text='{text}']")

    @staticmethod
    def content_desc_contains(desc: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//*[contains(@content-desc, '{desc}')]")

    @staticmethod
    def content_desc_exact(desc: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//*[@content-desc='{desc}']")

    @staticmethod
    def button_with_text(text: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//android.widget.Button[@text='{text}']")

    @staticmethod
    def text_view_with_text(text: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//android.widget.TextView[@text='{text}']")

    @staticmethod
    def edit_text_with_hint(hint: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//android.widget.EditText[@hint='{hint}']")

    @staticmethod
    def scrollable_with_text(text: str) -> tuple:
        return (
            BaseLocators.BY_XPATH,
            f"//android.widget.ScrollView//*[contains(@text, '{text}')]",
        )

    @staticmethod
    def any_element_with_text(text: str) -> tuple:
        return (BaseLocators.BY_XPATH, f"//*[@text='{text}' or @content-desc='{text}']")

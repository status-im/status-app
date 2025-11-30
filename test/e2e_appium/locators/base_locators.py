from appium.webdriver.common.appiumby import AppiumBy


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

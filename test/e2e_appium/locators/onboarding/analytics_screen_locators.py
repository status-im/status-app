from ..base_locators import BaseLocators

class AnalyticsScreenLocators(BaseLocators):

    ANALYTICS_PAGE_BY_CONTENT_DESC = BaseLocators.label_contains(
        "Help us improve Status"
    )
    SHARE_USAGE_DATA_BUTTON = BaseLocators.label_exact("Share usage data")
    # On Android content-desc contains "[tid:btnDontShare]";
    # on iOS label is "Skip sharing" and name contains "btnDontShare".
    NOT_NOW_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:btnDontShare]') "
        "or contains(@name, 'btnDontShare')]"
    )

    ONBOARDING_CONTAINER = BaseLocators.object_name_contains(
        "startupOnboardingLayout"
    )

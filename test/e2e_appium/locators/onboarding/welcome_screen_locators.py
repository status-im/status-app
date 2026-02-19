from ..base_locators import BaseLocators

class WelcomeScreenLocators(BaseLocators):

    # Screen identification
    WELCOME_PAGE = BaseLocators.label_contains("Welcome to Status")

    # On Android content-desc is "Create profile [tid:btnCreateProfile]";
    # on iOS label is "Create profile" and name contains "btnCreateProfile".
    CREATE_PROFILE_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:btnCreateProfile]') "
        "or contains(@name, 'btnCreateProfile')]"
    )
    LOGIN_BUTTON = BaseLocators.label_exact("Log in")

    ONBOARDING_LAYOUT = BaseLocators.object_name_contains("startupOnboardingLayout")

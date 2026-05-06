from ..base_locators import BaseLocators

class WelcomeScreenLocators(BaseLocators):

    # Screen identification
    WELCOME_PAGE = BaseLocators.label_contains("Welcome to Status")

    CREATE_PROFILE_BUTTON = BaseLocators.tid("btnCreateProfile")
    LOGIN_BUTTON = BaseLocators.label_exact("Log in")

    ONBOARDING_LAYOUT = BaseLocators.object_name_contains("startupOnboardingLayout")

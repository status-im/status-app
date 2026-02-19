from ..base_locators import BaseLocators


class CreateProfileScreenLocators(BaseLocators):

    CREATE_PROFILE_SCREEN = BaseLocators.label_contains("Create profile")
    LETS_GO_BUTTON = BaseLocators.label_exact("Let's go!")
    USE_RECOVERY_PHRASE_BUTTON = BaseLocators.label_exact("Use a recovery phrase")
    USE_KEYCARD_BUTTON = BaseLocators.label_exact("Use an empty Keycard")

    ONBOARDING_CONTAINER = BaseLocators.object_name_contains(
        "startupOnboardingLayout"
    )

    LETS_GO_BUTTON_BY_ID = BaseLocators.object_name_contains("btnCreateWithPassword")
    CREATE_PROFILE_PARTIAL = BaseLocators.object_name_contains("CreateProfilePage")

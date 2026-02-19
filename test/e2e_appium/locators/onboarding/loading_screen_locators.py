from ..base_locators import BaseLocators


class LoadingScreenLocators(BaseLocators):

    # Loading screen container (full ID — Android only, kept for reference)
    SPLASH_SCREEN = BaseLocators.id(
        "QGuiApplication.mainWindow.startupOnboardingLayout.ProfileCreationFlow_QMLTYPE_206.splashScreenV2"
    )

    # Cross-platform partial match
    SPLASH_SCREEN_PARTIAL = BaseLocators.object_name_contains("splashScreenV2")

    PROGRESS_BAR = BaseLocators.object_name_contains("StatusProgressBar")

    ONBOARDING_CONTAINER = BaseLocators.object_name_contains(
        "startupOnboardingLayout"
    )

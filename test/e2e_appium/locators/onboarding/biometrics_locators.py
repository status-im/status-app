from ..base_locators import BaseLocators


class BiometricsLocators(BaseLocators):
    """Locators for the biometrics prompt displayed during onboarding."""

    BIOMETRICS_DIALOG_TITLE = BaseLocators.text_contains("Enable biometrics")
    MAYBE_LATER_BUTTON = BaseLocators.content_desc_contains("tid:btnDontEnableBiometrics")
    ENABLE_BUTTON = BaseLocators.content_desc_contains("tid:btnEnableBiometrics")


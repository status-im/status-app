from ..base_locators import BaseLocators


class BiometricsLocators(BaseLocators):
    """Locators for the biometrics prompt displayed during onboarding."""

    BIOMETRICS_DIALOG_TITLE = BaseLocators.label_contains("Enable biometrics")
    MAYBE_LATER_BUTTON = BaseLocators.tid("btnDontEnableBiometrics")
    ENABLE_BUTTON = BaseLocators.tid("btnEnableBiometrics")

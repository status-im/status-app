from ..base_locators import BaseLocators


class BiometricsLocators(BaseLocators):
    """Locators for the biometrics prompt displayed during onboarding."""

    BIOMETRICS_DIALOG_TITLE = BaseLocators.label_contains("Enable biometrics")
    # On Android content-desc contains "tid:btnDontEnableBiometrics";
    # on iOS name contains "btnDontEnableBiometrics".
    MAYBE_LATER_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, 'tid:btnDontEnableBiometrics') "
        "or contains(@name, 'btnDontEnableBiometrics')]"
    )
    ENABLE_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, 'tid:btnEnableBiometrics') "
        "or contains(@name, 'btnEnableBiometrics')]"
    )

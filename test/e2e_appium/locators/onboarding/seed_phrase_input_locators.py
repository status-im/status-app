from ..base_locators import BaseLocators


class SeedPhraseInputLocators(BaseLocators):

    # TODO: Replace fallbacks and alts with accessibility_id/tid

    SEED_PHRASE_INPUT_SCREEN_CREATE = BaseLocators.accessibility_id(
        "Create profile using a recovery phrase"
    )
    SEED_PHRASE_INPUT_SCREEN_LOGIN = BaseLocators.accessibility_id(
        "Log in with your Status recovery phrase"
    )

    @staticmethod
    def get_tab_locators(word_count: int) -> list:
        base = str(word_count)
        return [BaseLocators.accessibility_id(f"{base} word(s)")]

    CONTINUE_BUTTON = BaseLocators.tid("btnContinue")
    IMPORT_BUTTON = BaseLocators.accessibility_id("Import")
    IMPORT_BUTTON_ALT = BaseLocators.accessibility_id("Import seed phrase")

    INVALID_SEED_TEXT = BaseLocators.accessibility_id("Invalid seed phrase")
    INVALID_SEED_TEXT_ALT = BaseLocators.accessibility_id("Seed phrase is invalid")

    @staticmethod
    def get_seed_word_input_field(position: int) -> tuple:
        return BaseLocators.xpath(
            f"//*[contains(@resource-id, 'enterSeedPhraseInputField{position}')]"
        )

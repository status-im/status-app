from ..base_locators import BaseLocators


class BackupSeedLocators(BaseLocators):
    MODAL_ROOT = BaseLocators.xpath("//*[contains(@resource-id, 'BackupSeedModal')]")

    # Scroll container inside the modal (from XML: BackupSeedModal.StatusScrollView_QMLTYPE_*)
    SCROLL_CONTAINER = BaseLocators.xpath(
        "//*[contains(@resource-id,'BackupSeedModal') and contains(@resource-id,'StatusScrollView')]"
    )

    ACK_HAVE_PEN = BaseLocators.accessibility_id("I have a pen and paper")
    ACK_WRITE_DOWN = BaseLocators.accessibility_id(
        "I am ready to write down my recovery phrase"
    )
    ACK_STORE_IT = BaseLocators.accessibility_id("I know where I’ll store it")

    # Reveal step container (helps scoping seed word extraction)
    REVEAL_CONTAINER = BaseLocators.accessibility_id("Show recovery phrase")

    REVEAL_BUTTON = BaseLocators.tid("btnReveal")
    SEED_WORD_INPUT_ANY = BaseLocators.id("seedWordInput")
    # Test-mode TIDs: expose each word via Accessible.name with objectName seedWordText_<n>
    SEED_WORD_TEXT_NODES = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:seedWordText_') "
        "or contains(@resource-id, 'seedWordText_')]"
    )

    NEXT_BUTTON = BaseLocators.accessibility_id("I've backed up phrase")
    CONTINUE_BUTTON = BaseLocators.accessibility_id("Continue")
    DONE_BUTTON = BaseLocators.accessibility_id("Done")
    DELETE_CHECKBOX = BaseLocators.accessibility_id(
        "Permanently remove your recovery phrase from the Status app — you will not be able to view it again"
    )
    # Confirm step container and inputs (single-screen, four-input UI)
    CONFIRM_STEP_CONTAINER = BaseLocators.accessibility_id("Confirm recovery phrase")
    CONFIRM_INPUTS_ANY = BaseLocators.xpath(
        "//*[contains(@resource-id,'BackupSeedModal')]//*[contains(@resource-id,'seedInput_')]"
    )
    FINAL_ACK_CHECKBOX = BaseLocators.accessibility_id(
        "I acknowledge that Status will not be able to show me my recovery phrase again."
    )
    COMPLETE_AND_DELETE_BUTTON = BaseLocators.accessibility_id(
        "Complete & Delete My Recovery Phrase"
    )
    NOT_NOW_BUTTON = BaseLocators.accessibility_id("Not Now")

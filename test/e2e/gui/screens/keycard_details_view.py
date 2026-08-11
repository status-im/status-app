import allure

from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import onboarding_names


class KeycardDetailsView(QObject):
    def __init__(self):
        super().__init__(onboarding_names.mainWindow_keycardDetailsPage)

        self.keycard_view_title = TextLabel(onboarding_names.keycardDetailsTitle)
        self.keycard_view_import_new_keypair = Button(onboarding_names.onboardingKeycardDetailsImportNewKeypair)
        self.keycard_view_import_seed_phrase = Button(onboarding_names.onboardingKeycardDetailsImportSeedPhrase)

    @allure.step('Import a new keypair to Keycard and create new profile')
    def import_a_new_keypair(self):
        self.keycard_view_import_new_keypair.click()
        from gui.components.keycard.management_popup import KeycardManagementPopup
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Import a key pair from recovery phrase')
    def import_from_recovery_phrase(self):
        self.keycard_view_import_seed_phrase.click()
        from gui.components.keycard.management_popup import KeycardManagementPopup
        return KeycardManagementPopup().wait_until_appears()

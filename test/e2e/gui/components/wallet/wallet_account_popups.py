from constants.wallet import *
from gui.screens.settings_keycard import KeycardSettingsView
from gui.screens.settings_wallet import *
from gui.components.emoji_popup import EmojiPopup
from gui.components.authenticate_popup import AuthenticatePopup
from gui.components.wallet.back_up_your_seed_phrase_popup import BackUpYourSeedPhrasePopUp
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import names, onboarding_names

GENERATED_PAGES_LIMIT = 20


class AccountPopup(QObject):
    def __init__(self):
        super(AccountPopup, self).__init__(names.mainWallet_AddEditAccountPopup_Content)

        self.add_wallet_account_popup = QObject(names.mainWallet_AddEditAccountPopup_Content)
        self._scroll = Scroll(names.generalView_StatusScrollView)
        self._name_text_edit = TextEdit(names.mainWallet_AddEditAccountPopup_AccountName)
        self._name_text_input = QObject(names.mainWallet_AddEditAccountPopup_AccountNameComponent)
        self._emoji_button = Button(names.mainWallet_AddEditAccountPopup_AccountEmojiPopupButton)
        self._color_radiobutton = QObject(names.color_StatusColorRadioButton)
        self._popup_header_title = TextLabel(names.mainWallet_AddEditAccountPopup_HeaderTitle)
        self._emoji_id_in_title = QObject(names.mainWallet_AddEditAccountPopup_HeaderEmoji)
        # origin
        self._origin_combobox = QObject(names.mainWallet_AddEditAccountPopup_SelectedOrigin)
        self._watched_address_origin_item = QObject(names.mainWallet_AddEditAccountPopup_OriginOptionWatchOnlyAcc)
        self._new_master_key_origin_item = QObject(names.mainWallet_AddEditAccountPopup_OriginOptionNewMasterKey)
        self._existing_origin_item = QObject(names.addAccountPopup_OriginOption_StatusListItem)
        self._use_keycard_button = QObject(names.mainWallet_AddEditAccountPopup_MasterKey_GoToKeycardSettingsOption)
        # derivation
        self._address_text_edit = TextEdit(names.mainWallet_AddEditAccountPopup_AccountWatchOnlyAddress)
        self._add_save_account_confirmation_button = Button(names.mainWallet_AddEditAccountPopup_PrimaryButton)
        self.copy_derivation_path_button = Button(names.mainWallet_AddEditAccountPopup_CopyDerivationPathButton)
        self._edit_derivation_path_button = Button(names.mainWallet_AddEditAccountPopup_EditDerivationPathButton)
        self._derivation_path_combobox_button = Button(
            names.mainWallet_AddEditAccountPopup_PreDefinedDerivationPathsButton)
        self._derivation_path_list_item = QObject(names.mainWallet_AddEditAccountPopup_derivationPath)
        self._reset_derivation_path_button = Button(names.mainWallet_AddEditAccountPopup_ResetDerivationPathButton)
        self._derivation_path_text_edit = TextEdit(names.mainWallet_AddEditAccountPopup_DerivationPathInput)
        self._address_combobox_button = Button(names.mainWallet_AddEditAccountPopup_GeneratedAddressComponent)
        self._non_eth_checkbox = CheckBox(names.mainWallet_AddEditAccountPopup_NonEthDerivationPathCheckBox)
        self.non_ethereum_checkbox_indicator = QObject(names.nonEthCheckBoxIndicator)

    def verify_add_account_popup_present(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        driver.waitFor(lambda: self._popup_header_title.is_visible, timeout_msec)
        assert (getattr(self._popup_header_title.object, 'text')
                == WalletScreensHeaders.WALLET_ADD_ACCOUNT_POPUP_TITLE.value), \
            f"AccountPopup is not shown or has wrong title, \
                    current screen title is {getattr(self._popup_header_title.object, 'text')}"
        return self

    def verify_edit_account_popup_present(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        driver.waitFor(lambda: self._popup_header_title.exists, timeout_msec)
        assert (getattr(self._popup_header_title.object, 'text')
                == WalletScreensHeaders.WALLET_EDIT_ACCOUNT_POPUP_TITLE.value), \
            f"AccountPopup is not shown or has wrong title, \
                    current screen title is {getattr(self._popup_header_title.object, 'text')}"
        return self

    @allure.step('Set name for account')
    def set_name(self, value: str):
        self._name_text_edit.text = value
        return self

    @allure.step('Get error message')
    def get_error_message(self):
        return self._name_text_input.object.errorMessageCmp.text

    @allure.step('Set color for account')
    def set_color(self, value: str):
        if 'radioButtonColor' in self._color_radiobutton.real_name.keys():
            del self._color_radiobutton.real_name['radioButtonColor']
        colors = [str(item.radioButtonColor) for item in driver.findAllObjects(self._color_radiobutton.real_name)]
        assert value in colors, f'Color {value} not found in {colors}'
        self._color_radiobutton.real_name['radioButtonColor'] = value
        self._color_radiobutton.click()
        return self

    def set_random_color(self):
        if 'radioButtonColor' in self._color_radiobutton.real_name.keys():
            del self._color_radiobutton.real_name['radioButtonColor']
        colors = [str(item.radioButtonColor) for item in driver.findAllObjects(self._color_radiobutton.real_name)]
        random_color = random.choice(colors)
        self._color_radiobutton.real_name['radioButtonColor'] = random_color
        self._color_radiobutton.click()
        return random_color

    @allure.step('Set emoji for account')
    def set_emoji(self, value: str):
        self._emoji_button.click()
        EmojiPopup().wait_until_appears(timeout_msec=10000).select(value.strip(':'))
        return self

    @allure.step('Get emoji id from account header')
    def get_emoji_from_account_title(self):
        return str(getattr(self._emoji_id_in_title.object, 'emojiId'))

    @allure.step('Set eth address for account added from context menu')
    def set_eth_address(self, value: str):
        self._address_text_edit.text = value
        return self

    @allure.step('Set eth address for account added from plus button')
    def set_origin_watched_address(self, value: str):
        self._origin_combobox.click()
        self._watched_address_origin_item.click()
        assert getattr(self._origin_combobox.object, 'title') == WalletOrigin.WATCHED_ADDRESS_ORIGIN.value
        self._address_text_edit.text = value
        return self

    @allure.step('Set private key for account')
    def set_origin_private_key(self, value: str, private_key_name: str):
        self.open_add_new_account_popup().import_private_key(value, private_key_name)
        return self

    @allure.step('Click new master key item')
    def click_new_master_key(self, attempts: int = 2):
        for _ in range(attempts):
            try:
                self._new_master_key_origin_item.click()
                return AddNewAccountPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Add new account popup is not shown within {attempts} retries')

    @allure.step('Set new seed phrase for account')
    def set_origin_new_seed_phrase(self, value: str):
        self.open_add_new_account_popup().generate_new_master_key(value)
        return self

    @allure.step('Open add new account popup')
    def open_add_new_account_popup(self):
        self._origin_combobox.click()
        self.click_new_master_key()
        return AddNewAccountPopup().wait_until_appears()

    @allure.step('Set derivation path for account')
    def set_derivation_path(self, value: str, index: int, password: str):
        self._edit_derivation_path_button.hover().click()
        AuthenticatePopup().wait_until_appears().authenticate(password)
        self._scroll.vertical_scroll_down(self._derivation_path_text_edit)
        if value in [_.value for _ in DerivationPathName]:
            self._derivation_path_combobox_button.click()
            self._derivation_path_list_item.real_name[
                'objectName'] = "AddAccountPopup-PreDefinedDerivationPath-" + value
            self._derivation_path_list_item.click()
            # del self._derivation_path_list_item.real_name['title']
            self._address_combobox_button.click()
            GeneratedAddressesList().select(index)
            if value != DerivationPathName.ETHEREUM.value:
                self._scroll.vertical_scroll_down(self._non_eth_checkbox)
                self.non_ethereum_checkbox_indicator.click()
        else:
            self._derivation_path_text_edit.type_text(str(index))
        return self

    @allure.step('Click continue in keycard settings')
    def continue_in_keycard_settings(self):
        self._origin_combobox.click()
        self.click_new_master_key()
        self._use_keycard_button.click()
        return KeycardSettingsView().wait_until_appears(), 'Keycard settings view was not opened'

    @allure.step('Click confirmation (add account / save changes) button')
    def save_changes(self):
        # TODO https://github.com/status-im/status-app/issues/15345
        self._add_save_account_confirmation_button.click()
        return self


class EditAccountFromSettingsPopup(QObject):
    def __init__(self):
        super(EditAccountFromSettingsPopup, self).__init__(names.renameAccountModal)
        self.change_name_button = Button(names.editWalletSettings_renameButton)
        self.account_name_input = TextEdit(names.editWalletSettings_AccountNameInput)
        self.emoji_selector = QObject(names.editWalletSettings_EmojiSelector)
        self.color_radiobutton = QObject(names.editWalletSettings_ColorSelector)
        self.emoji_item = QObject(names.editWalletSettings_EmojiItem)

    @allure.step('Edit account')
    def edit_account(self, account_name):
        self.type_in_account_name(account_name)
        self.select_random_color_for_account()
        # self.select_random_emoji_for_account()
        self.change_name_button.click()

    @allure.step('Type in name for account')
    def type_in_account_name(self, value: str):
        self.account_name_input.text = value
        return self

    @allure.step('Select random color for account')
    def select_random_color_for_account(self):
        if 'radioButtonColor' in self.color_radiobutton.real_name.keys():
            del self.color_radiobutton.real_name['radioButtonColor']
        colors = [str(item.radioButtonColor) for item in driver.findAllObjects(self.color_radiobutton.real_name)]
        self.color_radiobutton.real_name['radioButtonColor'] = \
            random.choice([color for color in colors if color != '#2a4af5'])  # exclude status default color
        self.color_radiobutton.click()
        return self

    @allure.step('Click emoji button')
    def select_random_emoji_for_account(self):
        self.emoji_selector.click()
        EmojiPopup().wait_until_appears()
        emojis = [str(item.objectName) for item in driver.findAllObjects(self.emoji_item.real_name)]
        value = ((random.choice(emojis)).split('_', 1))[1]
        EmojiPopup().wait_until_appears().select(value)
        return self


class AddNewAccountPopup(QObject):

    def __init__(self):
        super(AddNewAccountPopup, self).__init__(names.mainWallet_AddEditAccountPopup_Content)
        self._import_private_key_button = Button(names.mainWallet_AddEditAccountPopup_MasterKey_ImportPrivateKeyOption)
        self._private_key_text_edit = TextEdit(names.mainWallet_AddEditAccountPopup_PrivateKey)
        self._private_key_name_text_edit = TextEdit(names.mainWallet_AddEditAccountPopup_PrivateKeyName)
        self._continue_button = Button(names.mainWallet_AddEditAccountPopup_PrimaryButton)
        self._import_seed_phrase_button = Button(names.mainWallet_AddEditAccountPopup_MasterKey_ImportSeedPhraseOption)
        self._generate_master_key_button = Button(
            names.mainWallet_AddEditAccountPopup_MasterKey_GenerateSeedPhraseOption)
        self._seed_phrase_12_words_button = Button(names.mainWallet_AddEditAccountPopup_12WordsButton)
        self._seed_phrase_18_words_button = Button(names.mainWallet_AddEditAccountPopup_18WordsButton)
        self._seed_phrase_24_words_button = Button(names.mainWallet_AddEditAccountPopup_24WordsButton)
        self._seed_phrase_word_text_edit = TextEdit(onboarding_names.mainWindow_statusSeedPhraseInputField_TextEdit)
        self._seed_phrase_phrase_key_name_text_edit = TextEdit(
            names.mainWallet_AddEditAccountPopup_ImportedSeedPhraseKeyName)
        self._seed_phrase_status_input = QObject(names.addAccountPopup_ImportedSeedPhraseKeyName_StatusInput)
        self._private_key_status_input = QObject(names.addAccountPopup_PrivateKeyName_StatusInput)
        self._already_added_error = QObject(names.enterSeedPhraseInvalidSeedText_StatusBaseText)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._generate_master_key_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Get error message')
    def get_error_message(self) -> str:
        return str(self._seed_phrase_status_input.object.errorMessageCmp.text)

    @allure.step('Get private key error message')
    def get_private_key_error_message(self) -> str:
        return str(self._private_key_status_input.object.errorMessageCmp.text)

    @allure.step('Import private key')
    def import_private_key(self, private_key: str, private_key_name: str) -> str:
        self.import_and_enter_private_key(private_key)
        self.enter_private_key_name(private_key_name)
        self.click_continue()
        return private_key_name

    @allure.step('Click import private key and enter private key')
    def import_and_enter_private_key(self, private_key: str):
        self._import_private_key_button.click()
        self._private_key_text_edit.text = private_key
        return self

    @allure.step('Enter private key name')
    def enter_private_key_name(self, private_key_name: str):
        self._private_key_name_text_edit.text = private_key_name
        return self

    @allure.step('Click continue')
    def click_continue(self):
        # TODO https://github.com/status-im/status-app/issues/15345
        self._continue_button.click()
        return self

    @allure.step('Import new seed phrase and continue')
    def import_new_seed_phrase(self, seed_phrase_words: list):
        self.enter_new_seed_phrase(seed_phrase_words)
        seed_phrase_name = ''.join([word[0] for word in seed_phrase_words[:10]])
        self.enter_seed_phrase_name(seed_phrase_name)
        self.click_continue()
        return seed_phrase_name

    @allure.step('Enter new seed phrase')
    def enter_new_seed_phrase(self, seed_phrase_words: list):
        # TODO https://github.com/status-im/status-app/issues/15345
        self._import_seed_phrase_button.click()
        if len(seed_phrase_words) == 12:
            self._seed_phrase_12_words_button.click()
        elif len(seed_phrase_words) == 18:
            self._seed_phrase_18_words_button.click()
        elif len(seed_phrase_words) == 24:
            self._seed_phrase_24_words_button.click()
        else:
            raise RuntimeError("Wrong amount of seed words", len(seed_phrase_words))
        for count, word in enumerate(seed_phrase_words, start=1):
            self._seed_phrase_word_text_edit.real_name['objectName'] = f'enterSeedPhraseInputField{count}'
            self._seed_phrase_word_text_edit.text = word
        return self

    @allure.step('Enter seed phrase name')
    def enter_seed_phrase_name(self, seed_phrase_name: str):
        self._seed_phrase_phrase_key_name_text_edit.text = seed_phrase_name
        return self

    @allure.step('Generate new seed phrase')
    def generate_new_master_key(self, name: str):
        self._generate_master_key_button.click()
        BackUpYourSeedPhrasePopUp().back_up_seed_phrase(name)

    @allure.step('Get text of error')
    def get_already_added_error(self):
        assert self._already_added_error.is_visible
        return self._already_added_error.object.text


class GeneratedAddressesList(QObject):

    def __init__(self):
        super().__init__(names.accountAddressSelectionModal)
        self.address_list_item = QObject(names.addAccountPopup_GeneratedAddress)
        self.paginator_page = QObject(names.page_StatusBaseButton)

    @allure.step('Select address in list')
    def select(self, index: int):
        self.address_list_item.real_name['objectName'] = 'AddAccountPopup-GeneratedAddress-' + str(index)

        selected_page_number = 1
        while selected_page_number != GENERATED_PAGES_LIMIT:
            if self.address_list_item.is_visible:
                self.address_list_item.click()
                self.paginator_page.wait_until_hidden()
                break

            else:
                selected_page_number += 1
                self.paginator_page.real_name['text'] = selected_page_number
                self.paginator_page.click()
                time.sleep(0.5)

import logging
import pathlib
import time
import typing

import allure

import configs
import constants.tesseract
from constants.onboarding import OnboardingScreensHeaders
import driver
from constants import ColorCodes
from driver.objects_access import walk_children
from gui.components.onboarding.language_selector import LanguageSelector
from gui.components.onboarding.login_by_syncing_checklist import LogInBySyncingChecklist
from gui.components.onboarding.login_users_list_popup import OnboardingLoginUsersPopup
from gui.components.onboarding.share_usage_data_popup import HelpUsImproveStatusView
from gui.components.os.open_file_dialogs import OpenFileDialog
from gui.components.picture_edit_popup import PictureEditPopup
from gui.components.splash_screen import SplashScreen
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import onboarding_names
from scripts.tools.image import Image
from scripts.utils.system_path import SystemPath

LOG = logging.getLogger(__name__)


class OnboardingWelcomeToStatusView(QObject):

    def __init__(self):
        super().__init__(onboarding_names.startupOnboardingLayout)
        self.create_profile_button = Button(onboarding_names.startupCreateProfileButton)
        self.log_in_button = Button(onboarding_names.startupLoginButton)
        self.approval_links = QObject(onboarding_names.startupApprovalLinks)
        self.language_selector = QObject(onboarding_names.startupLanguageSelector)

    @allure.step('Open language selector')
    def open_language_selector(self):
        self.language_selector.click()
        return LanguageSelector().wait_until_appears()

    @allure.step('Open Create your profile view')
    def open_create_your_profile_view(self) -> 'CreateYourProfileViewOnboarding':
        self.create_profile_button.click()
        help_us_view = HelpUsImproveStatusView()
        info_popup = help_us_view.open_info_popup()
        assert info_popup
        info_popup.close()
        help_us_view.not_now_button.click()
        return CreateYourProfileViewOnboarding().wait_until_appears()

    @allure.step('Open Sign by syncing form')
    def sync_existing_user(self) -> 'OnboardingSyncCodeView':
        self.log_in_button.click()
        HelpUsImproveStatusView().wait_until_appears().not_now_button.click()
        OnboardingLogIn().wait_until_appears().log_in_by_syncing_button.click()
        LogInBySyncingChecklist().wait_until_appears().complete()
        return OnboardingSyncCodeView().wait_until_appears()


class CreateYourProfileViewOnboarding(OnboardingWelcomeToStatusView):
    def __init__(self):
        super().__init__()
        self.lets_go_button = Button(onboarding_names.startFreshLetsGoButton)
        self.use_a_recovery_phrase_button = Button(onboarding_names.useRecoveryPhraseButton)
        self.use_an_empty_keycard_button = Button(onboarding_names.useEmptyKeycardButton)

    def open_password_view(self):
        self.lets_go_button.click()
        return OnboardingCreatePasswordView()

    def open_seed_phrase_view(self):
        self.use_a_recovery_phrase_button.click()
        return OnboardingImportSeedPhraseView()


class OnboardingLogIn(OnboardingWelcomeToStatusView):
    def __init__(self):
        super().__init__()
        self.enter_recovery_phrase_button = Button(onboarding_names.enterRecoveryPhraseButton)
        self.log_in_by_syncing_button = Button(onboarding_names.logInBySyncingButton)
        self.log_in_with_keycard_button = Button(onboarding_names.logInWithKeycardButton)


class OnboardingView(QObject):

    def __init__(self, object_name):
        super().__init__(object_name)
        self.back_button = Button(onboarding_names.mainWindow_onboardingBackButton_StatusRoundButton)


class OnboardingSyncCodeView(QObject):

    def __init__(self):
        super().__init__(onboarding_names.logInBySyncingView)
        self.enter_sync_code_button = Button(onboarding_names.switchTabBar_Enter_sync_code_StatusSwitchTabButton)
        self.paste_sync_code_button = Button(onboarding_names.mainWindow_Paste_StatusButton)
        self.syncing_enter_code_item = QObject(onboarding_names.mainWindow_syncingEnterCode_SyncingEnterCode)
        self.continue_button = Button(onboarding_names.mainWindow_nameInput_syncingEnterCode_Continue)
        self.sync_code_error_message = QObject(onboarding_names.syncCodeErrorMessage)

    @allure.step('Open enter sync code form')
    def open_enter_sync_code_form(self):
        self.enter_sync_code_button.click()
        return self

    @allure.step('Paste sync code')
    def click_paste_button(self):
        self.paste_sync_code_button.click()

    @property
    @allure.step('Get wrong sync code message')
    def get_sync_code_error_message(self) -> str:
        return str(self.sync_code_error_message.object.text)


class SyncCodeView(OnboardingView):

    def __init__(self):
        super(SyncCodeView, self).__init__(onboarding_names.mainWindow_SyncCodeView)
        self._enter_sync_code_button = Button(onboarding_names.switchTabBar_Enter_sync_code_StatusSwitchTabButton)
        self._paste_sync_code_button = Button(onboarding_names.mainWindow_Paste_StatusButton)
        self._syncing_enter_code_item = QObject(onboarding_names.mainWindow_syncingEnterCode_SyncingEnterCode)

    @allure.step('Open enter sync code form')
    def open_enter_sync_code_form(self):
        self._enter_sync_code_button.click()
        return self

    @allure.step('Paste sync code')
    def click_paste_button(self):
        self._paste_sync_code_button.click()

    @property
    @allure.step('Get wrong sync code message')
    def sync_code_error_message(self) -> str:
        return self._syncing_enter_code_item.object.syncCodeErrorMessage


class OnboardingProfileSyncedView(QObject):
    def __init__(self):
        super().__init__(onboarding_names.profileSyncedView)
        self.profile_synced_view = QObject(onboarding_names.profileSyncedView)
        self.log_in_button = Button(onboarding_names.startupLoginButton)
        self.profile_synced_view_header = QObject(onboarding_names.profileSyncedViewHeader)


class SyncDeviceFoundView(OnboardingView):

    def __init__(self):
        super(SyncDeviceFoundView, self).__init__(onboarding_names.mainWindow_SyncingDeviceView_found)
        self._sync_text_item = QObject(onboarding_names.sync_text_item)

    @property
    @allure.step('Get device_found_notifications')
    def device_found_notifications(self) -> typing.List:
        device_found_notifications = []
        for obj in driver.findAllObjects(self._sync_text_item.real_name):
            device_found_notifications.append(str(obj.text))
        return device_found_notifications


class SyncResultView(OnboardingView):

    def __init__(self):
        super(SyncResultView, self).__init__(onboarding_names.mainWindow_SyncDeviceResult)
        self.sync_result = QObject(onboarding_names.mainWindow_SyncDeviceResult)
        self.sign_in_button = Button(onboarding_names.mainWindow_Sign_in_StatusButton)
        self.synced_text_item = QObject(onboarding_names.synced_StatusBaseText)
        self.done_button = Button(onboarding_names.doneButton)

    @property
    @allure.step('Get device synced notifications')
    def device_synced_notifications(self) -> typing.List:
        device_synced_notifications = []
        for obj in driver.findAllObjects(self.synced_text_item.real_name):
            device_synced_notifications.append(str(obj.text))
        return device_synced_notifications

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = 10000):
        self.sign_in_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Sign in')
    def sign_in(self, attempts: int = 2):
        self.sign_in_button.click()
        try:
            return SplashScreen().wait_until_appears()
        except:
            assert attempts > 0, f'Next button was not clicked'
            self.sign_in(attempts - 1)


class OnboardingImportSeedPhraseView(QObject):
    def __init__(self):
        super().__init__(onboarding_names.onboardingImportSeedPhraseView)
        self.tab_12_words_button = Button(onboarding_names.tab12WordsButton)
        self.tab_18_words_button = Button(onboarding_names.tab18WordsButton)
        self.tab_24_words_button = Button(onboarding_names.tab24WordsButton)
        self.seed_phrase_input_text_edit = TextEdit(onboarding_names.seedPhraseInputField)
        self.continue_button = Button(onboarding_names.onboardingImportSeedPhraseContinueButton)
        self.invalid_seed_text = TextLabel(onboarding_names.invalidSeedText)

    def fill_in_seed_phrase_grid(self, seed_phrase: typing.List[str], autocomplete: bool):
        if len(seed_phrase) == 12:
            if not self.tab_12_words_button.is_checked:
                self.tab_12_words_button.click()
        elif len(seed_phrase) == 18:
            if not self.tab_18_words_button.is_checked:
                self.tab_18_words_button.click()
        elif len(seed_phrase) == 24:
            if not self.tab_24_words_button.is_checked:
                self.tab_24_words_button.click()
        else:
            raise RuntimeError("Wrong amount of seed words", len(seed_phrase))

        for index, word in enumerate(seed_phrase, start=1):
            self.seed_phrase_input_text_edit.real_name['objectName'] = f'enterSeedPhraseInputField{index}'
            if autocomplete:
                word_to_put = word
                if len(word) > 4:
                    word_to_put = word[:-1]
                self.seed_phrase_input_text_edit.text = word_to_put
                driver.type(self.seed_phrase_input_text_edit.object, "<Return>")
            else:
                self.seed_phrase_input_text_edit.text = word
                time.sleep(0.2)

    def continue_import(self):
        self.continue_button.click()
        return OnboardingCreatePasswordView()


class SeedPhraseInputView(OnboardingView):

    def __init__(self):
        super(SeedPhraseInputView, self).__init__(onboarding_names.mainWindow_SeedPhraseInputView)
        self._12_words_tab_button = Button(onboarding_names.switchTabBar_12_words_Button)
        self._18_words_tab_button = Button(onboarding_names.switchTabBar_18_words_Button)
        self._24_words_tab_button = Button(onboarding_names.switchTabBar_24_words_Button)
        self._seed_phrase_input_text_edit = TextEdit(onboarding_names.mainWindow_statusSeedPhraseInputField_TextEdit)
        self._import_button = Button(onboarding_names.mainWindow_Import_StatusButton)

    @property
    @allure.step('Get import button enabled state')
    def is_import_button_enabled(self) -> bool:
        return driver.waitForObjectExists(self._import_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @allure.step('Input seed phrase')
    def input_seed_phrase(self, seed_phrase: typing.List[str], autocomplete: bool):
        if len(seed_phrase) == 12:
            if not self._12_words_tab_button.is_checked:
                self._12_words_tab_button.click()
        elif len(seed_phrase) == 18:
            if not self._18_words_tab_button.is_checked:
                self._18_words_tab_button.click()
        elif len(seed_phrase) == 24:
            if not self._24_words_tab_button.is_checked:
                self._24_words_tab_button.click()
        else:
            raise RuntimeError("Wrong amount of seed words", len(seed_phrase))

        for index, word in enumerate(seed_phrase, start=1):
            self._seed_phrase_input_text_edit.real_name['objectName'] = f'enterSeedPhraseInputField{index}'
            if autocomplete:
                word_to_put = word
                if len(word) > 4:
                    word_to_put = word[:-1]
                self._seed_phrase_input_text_edit.text = word_to_put
                driver.type(self._seed_phrase_input_text_edit.object, "<Return>")
            else:
                self._seed_phrase_input_text_edit.text = word

    @allure.step('Import seed phrase')
    def import_seed_phrase(self):
        self._import_button.click()
        return YourProfileView().wait_until_appears()


class KeycardInitView(OnboardingView):

    def __init__(self):
        super().__init__(onboarding_names.mainWindow_KeycardInitView)
        self._message = TextLabel(onboarding_names.mainWindow_Plug_in_Keycard_reader_StatusBaseText)

    @property
    def message(self) -> str:
        return self._message.text


class YourProfileView(OnboardingView):

    def __init__(self):
        super(YourProfileView, self).__init__(onboarding_names.mainWindow_InsertDetailsView)
        self._upload_picture_button = Button(onboarding_names.updatePicButton_StatusRoundButton)
        self._profile_image = QObject(onboarding_names.mainWindow_statusRoundImage_StatusRoundedImage)
        self._display_name_text_field = TextEdit(onboarding_names.mainWindow_statusBaseInput_StatusBaseInput)
        self._erros_text_label = TextLabel(onboarding_names.mainWindow_errorMessage_StatusBaseText)
        self._next_button = Button(onboarding_names.mainWindow_Next_StatusButton)
        self._login_input_object = QObject(onboarding_names.mainWindow_nameInput_StatusInput)
        self._clear_icon = QObject(onboarding_names.mainWindow_clear_icon_StatusIcon)
        self._identicon_ring = QObject(onboarding_names.mainWindow_IdenticonRing)
        self._view_header_title = TextLabel(onboarding_names.mainWindow_Header_Title)
        self._image_crop_workflow = QObject(onboarding_names.profileImageCropper)

    def verify_profile_view_present(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        driver.waitFor(lambda: self._view_header_title.exists, timeout_msec)
        assert (getattr(self._view_header_title.object, 'text') ==
                OnboardingScreensHeaders.YOUR_PROFILE_SCREEN_TITLE.value), \
            f"YourProfileView is not shown or has wrong title, \
            current screen title is {getattr(self._view_header_title.object, 'text')}"
        return self

    @property
    @allure.step('Get next button enabled state')
    def is_next_button_enabled(self) -> bool:
        return driver.waitForObjectExists(self._next_button.real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @property
    @allure.step('Get profile image')
    def get_profile_image(self) -> Image:
        return self._profile_image.image

    @property
    @allure.step('Get error messages')
    def get_error_message(self) -> str:
        return self._erros_text_label.text if self._erros_text_label.is_visible else ''

    @allure.step('Set user display name')
    def set_display_name(self, value: str):
        self._display_name_text_field.clear().text = value
        return self

    @allure.step('Get user display name')
    def get_display_name(self) -> str:
        return str(self._display_name_text_field.object.text)

    @allure.step('Click clear button')
    def clear_field(self):
        self._clear_icon.click()
        return self

    @allure.step('Set profile picture without file upload dialog')
    def set_profile_picture(self, path) -> PictureEditPopup:
        image_cropper = driver.waitForObjectExists(self._image_crop_workflow.real_name)
        fileuri = pathlib.Path(str(path)).as_uri()
        image_cropper.cropImage(fileuri)
        return PictureEditPopup()

    @allure.step('Set profile picture with file dialog upload')
    def set_user_image(self, fp: SystemPath) -> PictureEditPopup:
        allure.attach(name='User image', body=fp.read_bytes(), attachment_type=allure.attachment_type.PNG)
        self._upload_picture_button.hover()
        self._upload_picture_button.click()
        file_dialog = OpenFileDialog().wait_until_appears()
        file_dialog.open_file(fp)
        return PictureEditPopup().wait_until_appears()

    @allure.step('Open Create Password View')
    def next(self, attempts: int = 2) -> 'OnboardingCreatePasswordView':
        self._next_button.click()
        try:
            return OnboardingCreatePasswordView()
        except Exception as err:
            if attempts:
                return self.next(attempts - 1)
            else:
                raise err


class YourEmojihashAndIdenticonRingView(OnboardingView):

    def __init__(self):
        super(YourEmojihashAndIdenticonRingView, self).__init__(onboarding_names.mainWindow_InsertDetailsView)
        self._profile_image = QObject(onboarding_names.mainWindow_welcomeScreenUserProfileImage_StatusSmartIdenticon)
        self._chat_key_text_label = TextLabel(onboarding_names.mainWindow_insertDetailsViewChatKeyTxt_StyledText)
        self._next_button = Button(onboarding_names.mainWindow_Next_StatusButton)
        self._emoji_hash = QObject(onboarding_names.mainWindow_EmojiHash)
        self._identicon_ring = QObject(onboarding_names.mainWindow_userImageCopy_StatusSmartIdenticon)
        self._view_header_title = TextLabel(onboarding_names.mainWindow_Header_Title)

    def verify_emojihash_view_present(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        driver.waitFor(lambda: self._view_header_title.exists, timeout_msec)
        assert (getattr(self._view_header_title.object, 'text') ==
                OnboardingScreensHeaders.YOUR_EMOJIHASH_AND_IDENTICON_RING_SCREEN_TITLE.value), \
            f"YourEmojihashAndIdenticonRingView is not shown or has wrong title, \
            current screen title is {getattr(self._view_header_title.object, 'text')}"
        return self

    @property
    @allure.step('Get profile image icon')
    def profile_image(self) -> Image:
        self._profile_image.image.update_view()
        return self._profile_image.image

    @property
    @allure.step('Get profile image icon without identicon ring')
    def cropped_profile_image(self) -> Image:
        # Profile image without identicon_ring
        self._profile_image.image.update_view()
        self._profile_image.image.crop(
            driver.UiTypes.ScreenRectangle(
                20, 20, self._profile_image.image.width - 40, self._profile_image.image.height - 40
            ))
        return self._profile_image.image

    @property
    @allure.step('Get chat key')
    def get_chat_key(self) -> str:
        return self._chat_key_text_label.text.split(':')[1].strip()

    @property
    @allure.step('Get emoji hash image')
    def get_emoji_hash(self) -> str:
        return str(getattr(self._emoji_hash.object, 'publicKey'))

    @allure.step('Go back')
    def back(self):
        self.back_button.click()
        return YourProfileView().wait_until_appears()

    @allure.step
    @allure.step('Verify: User image contains text')
    def is_user_image_contains(self, text: str):
        crop = driver.UiTypes.ScreenRectangle(
            20, 20, self._profile_image.image.width - 40, self._profile_image.image.height - 40
        )
        return self.profile_image.has_text(text, constants.tesseract.text_on_profile_image, crop=crop)

    @allure.step
    @allure.step('Verify: User image background color')
    def is_user_image_background_white(self):
        crop = driver.UiTypes.ScreenRectangle(
            20, 20, self._profile_image.image.width - 40, self._profile_image.image.height - 40
        )
        return self.profile_image.has_color(constants.Color.WHITE, crop=crop)


class CreatePasswordView(OnboardingView):
    def __init__(self):
        super(CreatePasswordView, self).__init__(onboarding_names.mainWindow_CreatePasswordView)
        self._new_password_text_field = TextEdit(onboarding_names.mainWindow_passwordViewNewPassword)
        self._confirm_password_text_field = TextEdit(onboarding_names.mainWindow_passwordViewNewPasswordConfirm)
        self._create_button = Button(onboarding_names.mainWindow_Create_password_StatusButton)
        self._password_view_object = QObject(onboarding_names.mainWindow_view_PasswordView)
        self._strength_indicator = QObject(
            onboarding_names.mainWindow_strengthInditactor_StatusPasswordStrengthIndicator)
        self._indicator_panel_object = QObject(onboarding_names.mainWindow_RowLayout)
        self.password_component_indicator = QObject(onboarding_names.mainWindow_ComponentIndicator)
        self._show_icon = QObject(onboarding_names.mainWindow_show_icon_StatusIcon)
        self._hide_icon = QObject(onboarding_names.mainWindow_hide_icon_StatusIcon)

    @allure.step('Set password in first field')
    def set_password_in_first_field(self, value: str):
        self._new_password_text_field.clear()
        self._new_password_text_field.type_text(value)

    @allure.step('Set password in confirmation field')
    def set_password_in_confirmation_field(self, value: str):
        self._confirm_password_text_field.clear()
        self._confirm_password_text_field.type_text(value)

    @allure.step('Set password and open Confirmation password view')
    def create_password(self, value: str) -> 'ConfirmPasswordView':
        self.set_password_in_first_field(value)
        self.set_password_in_confirmation_field(value)
        self.click_create_password()
        return ConfirmPasswordView().wait_until_appears()

    def click_create_password(self):
        self._create_button.click()
        time.sleep(1)
        return ConfirmPasswordView().wait_until_appears()

    @allure.step('Get password content from first field')
    def get_password_from_first_field(self) -> str:
        return str(self._new_password_text_field.object.displayText)

    @allure.step('Get password content from confirmation field')
    def get_password_from_confirmation_field(self) -> str:
        return str(self._confirm_password_text_field.object.displayText)

    @property
    @allure.step('Verify: Create password button enabled')
    def is_create_password_button_enabled(self) -> bool:
        return driver.waitForObjectExists(self._create_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @property
    @allure.step('Get strength indicator color')
    def strength_indicator_color(self) -> str:
        return self._strength_indicator.object.fillColor['name']

    @property
    @allure.step('Get strength indicator text')
    def strength_indicator_text(self) -> str:
        return self._strength_indicator.object.text

    @property
    @allure.step('Get indicator panel green messages')
    def green_indicator_messages(self) -> typing.List[str]:
        messages = []
        color = ColorCodes.GREEN.value

        for item in driver.findAllObjects(self.password_component_indicator.real_name):
            if str(item.color.name) == color:
                messages.append(str(item.text))
        return messages

    @property
    @allure.step('Get password error message')
    def password_error_message(self) -> str:
        return self._password_view_object.object.strengthenText

    @allure.step('Click show icon by index')
    def click_show_icon(self, index):
        show_icons = driver.findAllObjects(self._show_icon.real_name)
        driver.mouseClick(show_icons[index])

    @allure.step('Click hide icon by index')
    def click_hide_icon(self, index):
        hide_icons = driver.findAllObjects(self._hide_icon.real_name)
        driver.mouseClick(hide_icons[index])

    @allure.step('Go back')
    def back(self):
        self.back_button.click()
        return YourEmojihashAndIdenticonRingView().wait_until_appears()


class OnboardingCreatePasswordView(OnboardingView):

    def __init__(self):
        super(OnboardingCreatePasswordView, self).__init__(onboarding_names.mainWindow_CreatePasswordView)
        self.choose_password_field = TextEdit(onboarding_names.choosePasswordField)
        self.repeat_password_field = TextEdit(onboarding_names.repeatPasswordField)
        self.confirm_password_button = Button(onboarding_names.confirmPasswordButton)
        self.create_password_view = QObject(onboarding_names.createPasswordView)
        self.password_strength_indicator = QObject(onboarding_names.passwordStrengthIndicator)
        self.password_component_indicator = QObject(onboarding_names.passwordComponentIndicator)

    @allure.step('Set password and open Confirmation password view')
    def create_password(self, value: str):
        self.set_password_in_first_field(value)
        self.set_password_in_repeat_field(value)
        self.confirm_password_button.click()
        if configs.system.get_platform() == "Darwin":
            biometrics_view = OnboardingBiometricsView().wait_until_appears()
            assert biometrics_view.yes_use_biometrics_button.is_visible, f"Use biometrics button is not found"
            biometrics_view.maybe_later()

    @allure.step('Fill in choose password field')
    def set_password_in_first_field(self, value: str):
        self.choose_password_field.clear()
        self.choose_password_field.type_text(value)

    @allure.step('Repeat password')
    def set_password_in_repeat_field(self, value: str):
        self.repeat_password_field.clear()
        self.repeat_password_field.type_text(value)

    @property
    @allure.step('Get error message')
    def get_error_message(self):
        return str(self.create_password_view.object.errorMsgText)

    @property
    @allure.step('Get strength indicator color')
    def strength_indicator_color(self) -> str:
        return self.password_strength_indicator.object.fillColor['name']

    @property
    @allure.step('Get strength indicator text')
    def strength_indicator_text(self) -> str:
        return self.password_strength_indicator.object.text

    @property
    @allure.step('Get indicator panel green messages')
    def green_indicator_messages(self) -> typing.List[str]:
        messages = []
        color = ColorCodes.GREEN.value

        for item in driver.findAllObjects(self.password_component_indicator.real_name):
            if str(item.color.name) == color:
                messages.append(str(item.text))
        return messages

    @property
    @allure.step('Get password error message')
    def password_error_message(self) -> str:
        return self.create_password_view.object.errorMsgText


class ConfirmPasswordView(OnboardingView):

    def __init__(self):
        super(ConfirmPasswordView, self).__init__(onboarding_names.mainWindow_ConfirmPasswordView)
        self._confirm_password_text_field = TextEdit(onboarding_names.mainWindow_confirmAgainPasswordInput)
        self._confirm_button = Button(onboarding_names.mainWindow_Finalise_Status_Password_Creation_StatusButton)
        self._confirmation_password_view_object = QObject(
            onboarding_names.mainWindow_passwordView_PasswordConfirmationView)

    @property
    @allure.step('Get finalise password creation button enabled state')
    def is_confirm_password_button_enabled(self) -> bool:
        return driver.waitForObjectExists(self._confirm_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @property
    @allure.step('Get confirmation error message')
    def confirmation_error_message(self) -> str:
        for child in walk_children(self._confirmation_password_view_object.object):
            if getattr(child, 'id', '') == 'errorTxt':
                return str(child.text)

    @allure.step('Set password')
    def set_password(self, value: str):
        self._confirm_password_text_field.clear()
        self._confirm_password_text_field.type_text(value)

    @allure.step('Click confirm password')
    def click_confirm_password(self):
        self._confirm_button.click()

    @allure.step('Confirm password')
    def confirm_password(self, value: str):
        self.set_password(value)
        self._confirm_button.click()

    @allure.step('Go back')
    def back(self):
        self.back_button.click()
        return OnboardingCreatePasswordView().wait_until_appears()

    @allure.step('Get password content from confirmation again field')
    def get_password_from_confirmation_again_field(self) -> str:
        return str(self._confirm_password_text_field.object.displayText)


class BiometricsView(OnboardingView):
    def __init__(self):
        super(BiometricsView, self).__init__(onboarding_names.mainWindow_TouchIDAuthView)
        self._yes_use_touch_id_button = Button(onboarding_names.mainWindow_touchIdYesUseTouchIDButton)
        self._prefer_password_button = Button(onboarding_names.mainWindow_touchIdIPreferToUseMyPasswordText)

    @allure.step('Select prefer password')
    def prefer_password(self):
        self._prefer_password_button.click()
        self.wait_until_hidden()

    @allure.step('Verify TouchID button')
    def is_touch_id_button_visible(self):
        return self._yes_use_touch_id_button.is_visible


class OnboardingBiometricsView(OnboardingView):

    def __init__(self):
        super(OnboardingBiometricsView, self).__init__(onboarding_names.enableBiometricsView)
        self.yes_use_biometrics_button = Button(onboarding_names.enableBiometricsButton)
        self.maybe_later_button = Button(onboarding_names.dontEnableBiometricsButton)

    @allure.step('Select maybe later option')
    def maybe_later(self):
        self.maybe_later_button.click()
        self.wait_until_hidden()


class ReturningLoginView(QObject):

    def __init__(self):
        super().__init__(onboarding_names.mainWindow_LoginView)
        self.user_selector_button = Button(onboarding_names.userSelectorButton)
        self.login_password_input = TextEdit(onboarding_names.loginView_passwordInput)
        self.login_button = Button(onboarding_names.loginButton)

        self._arrow_right_button = Button(onboarding_names.loginView_submitBtn)
        self._current_user_name_label = TextLabel(onboarding_names.loginView_currentUserNameLabel)
        self._change_account_button = Button(onboarding_names.loginView_changeAccountBtn)
        self._accounts_combobox = QObject(onboarding_names.accountsView_accountListPanel)
        self._password_object = QObject(onboarding_names.mainWindow_txtPassword_Input)
        self._add_new_user_item = QObject(onboarding_names.loginView_addNewUserItem_AccountMenuItemPanel)
        self._add_existing_user_item = QObject(onboarding_names.loginView_addExistingUserItem_AccountMenuItemPanel)
        self._use_password_instead = QObject(onboarding_names.mainWindowUsePasswordInsteadStatusBaseText)
        self.password_box = QObject(onboarding_names.loginView_passwordBox)

    @allure.step('Log in user')
    def log_in(self, account):
        if str(self.user_selector_button.object.label) != account.name:
            self.user_selector_button.click()
            self.select_user_by_name(account.name)
        self.login_password_input.click()
        self.login_password_input.clear()
        self.login_password_input.type_text(account.password)
        self.login_button.click()
        return SplashScreen()

    @allure.step('Add existing user')
    def add_existing_status_user(self):
        self.user_selector_button.click()
        OnboardingLoginUsersPopup().wait_until_appears().create_profile_button.click()
        HelpUsImproveStatusView().not_now_button.click()
        return CreateYourProfileViewOnboarding().wait_until_appears()

    @allure.step('Select user by name')
    def select_user_by_name(self, user_name):
        users_popup = OnboardingLoginUsersPopup()
        users_popup.select_user_by_name(user_name)

import allure
import pyperclip

import configs
import constants
import driver
from gui.components.context_menu import ContextMenu
from gui.components.settings.block_user_popup import BlockUserPopup
from gui.components.settings.review_contact_request_popup import AcceptIgnoreRequestFromProfile
from gui.components.settings.send_contact_request_popup import SendContactRequestFromProfile
from gui.components.settings.unblock_user_popup import UnblockUserPopup
from gui.components.share_profile_popup import ShareProfilePopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import names
from gui.screens.settings_profile import ProfileSettingsView


class ProfilePopup(QObject):

    def __init__(self):
        super().__init__(names.ProfileDialogView)
        self._profile_popup_content_item = QObject(names.ProfileDialogView)
        self._profile_image = QObject(names.ProfileHeader_userImage)
        self._user_name_label = TextLabel(names.ProfilePopup_displayName)
        self._edit_profile_button = Button(names.ProfilePopup_editButton)
        self._share_profile_button = Button(names.share_Profile_StatusFlatButton)
        self._chat_key_text_label = TextLabel(names.https_status_app_StatusBaseText)
        self._emoji_hash = QObject(names.profileDialog_userEmojiHash_EmojiHash)
        self._chat_key_copy_button = Button(names.copy_icon_CopyButton)
        self.profile_showcase_communities_view = QObject(names.profilePopup_communitiesView)
        self.profile_community_card = QObject(names.profilePopup_communityCard)
        self.profile_showcase_tab_communities = QObject(names.profilePopup_communityTab)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._profile_popup_content_item.wait_until_appears(timeout_msec)
        return self

    @property
    @allure.step('Get profile image')
    def profile_image(self):
        return self._profile_image.image

    @property
    @allure.step('Get image without identicon_ring')
    def cropped_profile_image(self):
        self._profile_image.image.update_view()
        self._profile_image.image.crop(
            driver.UiTypes.ScreenRectangle(
                15, 15, self._profile_image.image.width - 30, self._profile_image.image.height - 30
            ))
        return self._profile_image.image

    @property
    @allure.step('Get user name')
    def user_name(self) -> str:
        return self._user_name_label.text

    @property
    @allure.step('Get chat key')
    def get_chat_key_from_profile_link(self) -> str:
        chat_key = self._chat_key_text_label.text.split('https://status.app/u/')[1].strip()
        if '#' in chat_key:
            chat_key = chat_key.split('#')[1]
        return chat_key

    @property
    @allure.step('Copy chat key')
    def copy_chat_key(self) -> str:
        self._chat_key_copy_button.click()
        return pyperclip.paste()

    @allure.step('Verify: user image contains text')
    def is_user_image_contains(self, text: str):
        crop = driver.UiTypes.ScreenRectangle(
            15, 15, self._profile_image.image.width - 30, self._profile_image.image.height - 30
        )
        return self.profile_image.has_text(text, constants.tesseract.text_on_profile_image, crop=crop)

    @allure.step('Click edit profile button')
    def edit_profile(self):
        self._edit_profile_button.click()
        return ProfileSettingsView()

    @allure.step('Click share profile button')
    def share_profile(self):
        self._share_profile_button.click()
        return ShareProfilePopup()

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._emoji_hash.wait_until_appears(timeout_msec)
        return self

    @allure.step('Get communities cards names from profile')
    def communities_names_on_cards(self):
        self.profile_showcase_tab_communities.click()
        return [str(item.name) for item in
                driver.findAllObjects(self.profile_community_card.real_name)]


class ProfilePopupFromMembers(ProfilePopup):

    def __init__(self):
        super(ProfilePopupFromMembers, self).__init__()
        self._send_request_button = Button(names.send_contact_request_StatusButton)
        self._review_request_button = Button(names.review_contact_request_StatusButton)
        self._send_message_button = Button(names.send_Message_StatusButton)
        self._unblock_button = Button(names.unblock_user_StatusButton)
        self._menu_button = Button(names.menuButton_StatusFlatButton)
        self._block_user_menu_item = Button(names.block_user_StatusMenuItem)
        self._add_nickname_menu_item = Button(names.add_nickname_StatusMenuItem)

    @allure.step('Click send request button')
    def send_request(self):
        self._send_request_button.click()
        return SendContactRequestFromProfile().wait_until_appears()

    @allure.step('Get send request button visibilty state')
    def is_send_request_button_visible(self):
        return self._send_request_button.is_visible

    @allure.step('Click review contact request button')
    def review_contact_request(self):
        self._review_request_button.wait_until_appears(15000)
        self._review_request_button.click()
        return AcceptIgnoreRequestFromProfile().wait_until_appears()

    @allure.step('Get send message button visibility state')
    def is_send_message_button_visible(self):
        return self._send_message_button.is_visible

    @allure.step('Click menu button')
    def click_menu_button(self):
        self._menu_button.click()

    @allure.step('Choose option from context menu')
    def choose_context_menu_option(self, value: str):
        self.click_menu_button()
        ContextMenu().select(value)

    @allure.step('Block user from menu')
    def block_user(self):
        self.click_menu_button()
        self._block_user_menu_item.click()
        return BlockUserPopup().wait_until_appears()

    @allure.step('Get unblock button visibility state')
    def is_unblock_button_visible(self):
        return self._unblock_button.is_visible

    @allure.step('Unblock user from menu')
    def unblock_user(self):
        self._unblock_button.click()
        return UnblockUserPopup().wait_until_appears()

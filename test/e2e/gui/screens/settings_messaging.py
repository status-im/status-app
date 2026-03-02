import time
import typing

import allure

import configs.timeouts
import driver
from driver.objects_access import walk_children
from helpers.chat_helper import skip_message_backup_popup_if_visible
from gui.components.settings.block_user_popup import BlockUserPopup
from gui.components.settings.respond_to_id_request_popup import RespondToIDRequestPopup
from gui.components.settings.send_contact_request_popup import SendContactRequest
from gui.components.settings.unblock_user_popup import UnblockUserPopup
from gui.components.settings.verify_identity_popup import VerifyIdentityPopup

from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.list import List
from gui.objects_map import settings_names
from gui.screens.messages import MessagesScreen
from scripts.tools.image import Image
from gui.screens.settings import *


class MessagingSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_MessagingView)
        self.contacts_button = Button(settings_names.contactsListItem_btn_StatusContactRequestsIndicatorListItem)
        self.always_ask_button = Button(settings_names.always_ask_radioButton_StatusRadioButton)
        self.always_show_button = Button(settings_names.always_show_radioButton_StatusRadioButton)
        self.never_ask_button = Button(settings_names.never_show_radioButton_StatusRadioButton)
        self.allow_contact_requests_section = QObject(settings_names.allowNewContactRequestsSection)
        self.allow_contact_requests_toggle = CheckBox(settings_names.allowNewContactRequestsSectionToggle)

    @property
    @allure.step('Get pending contact requests count')
    def pending_requests_count(self) -> int:
        return int(self.contacts_button.object.requestsCount)

    @allure.step('Open contacts settings')
    def open_contacts_settings(self) -> 'ContactsSettingsView':
        self.contacts_button.click()
        return ContactsSettingsView()

    @allure.step('Switch allow new contact requests toggle')
    def switch_allow_contact_requests_toggle(self, value: bool):
        self.allow_contact_requests_toggle.set(value)


class ContactItem:

    def __init__(self, obj):
        self.object = obj
        self.icon: typing.Optional[Image] = None
        self.contact: typing.Optional[Image] = None
        self._accept_button: typing.Optional[Button] = None
        self._reject_button: typing.Optional[Button] = None
        self._open_canvas_button: typing.Optional[Button] = None
        self.init_ui()

    def __repr__(self):
        return self.contact

    def init_ui(self):
        self.contact = str(self.object.userName)
        for child in walk_children(self.object):
            if str(getattr(child, 'id', '')) == 'iconOrImage':
                self.icon = Image(driver.objectMap.realName(child))
            elif str(getattr(child, 'objectName', '')) == 'moreBtn':
                self._open_canvas_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'objectName', '')) == 'acceptBtn':
                self._accept_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'objectName', '')) == 'declineBtn':
                self._reject_button = Button(real_name=driver.objectMap.realName(child))
            elif str(getattr(child, 'objectName', '')) == 'chat-icon':
                self._chat_button = Button(real_name=driver.objectMap.realName(child))

    @allure.step('Accept request')
    def accept(self) -> MessagesScreen:
        assert self._accept_button is not None, 'Button not found'
        self._accept_button.click()
        skip_message_backup_popup_if_visible()
        return MessagesScreen().wait_until_appears()

    @allure.step('Reject request')
    def reject(self):
        assert self._reject_button is not None, 'Button not found'
        self._reject_button.click()

    @allure.step('Open more options popup')
    def open_more_options_popup(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC, attempt: int = 2):
        try:
            self._open_canvas_button.click()
            driver.waitFor(lambda: ContactsSettingsView()._view_profile_item.is_visible, timeout_msec)
            return self
        except:
            if attempt:
                self._open_canvas_button.click(attempt - 1)
                return self
            else:
                raise LookupError(f"Popup didn't appear")


class ContactsSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_ContactsView)
        self._contact_request_button = Button(settings_names.mainWindow_Send_contact_request_to_chat_key_StatusButton)
        self._pending_request_tab = Button(settings_names.contactsTabBar_Pending_Requests_StatusTabButton)
        self._contacts_tab = Button(settings_names.contactsTabBar_Contacts_StatusTabButton)
        self._blocked_tab = Button(settings_names.contactsTabBar_Blocked_StatusTabButton)
        self.contact_item = QObject(settings_names.contactRequestItemSettings)
        self._pending_request_sent_panel = QObject(
            settings_names.settingsContentBaseScrollView_sentRequests_ContactsListPanel)
        self.section_header = QObject(settings_names.settingsContentBaseScrollView_ContactListPanel_Header)
        self._pending_request_received_panel = QObject(
            settings_names.settingsContentBaseScrollView_receivedRequests_ContactsListPanel)
        self._contacts_panel = QObject(settings_names.settingsContentBaseScrollView_mutualContacts_ContactsListPanel)
        self.invite_friends_button = QObject(settings_names.settingsContentBaseScrollView_Invite_friends_StatusButton)
        self._no_friends_item = QObject(settings_names.settingsContentBaseScrollView_NoFriendsRectangle)
        # more options on contact
        self._verify_identity_item = QObject(settings_names.verify_Identity_StatusMenuItem)
        self._respond_to_id_request_item = QObject(settings_names.respond_to_ID_Request_StatusMenuItem)
        self._view_profile_item = QObject(settings_names.view_Profile_StatusMenuItem)
        self._respond_to_id_request_button = Button(
            settings_names.settingsContentBaseScrollView_Respond_to_ID_Request_StatusFlatButton)
        self._unblock_item = QObject(settings_names.unblock_user_StatusMenuItem)
        self._block_item = QObject(settings_names.block_user_StatusMenuItem)

    @property
    @allure.step('Get contact items')
    def contact_items(self, attempts: int = 2) -> typing.List[ContactItem]:
        for _ in range(attempts):
            try:
                contact_items = driver.findAllObjects(self.contact_item.wait_until_appears().real_name)
                if contact_items:
                    return [ContactItem(item) for item in contact_items]
            except Exception:
                pass
        raise LookupError('Contact requests are not found')

    @property
    @allure.step('Get title of list with sent pending requests')
    def pending_request_sent_list_title(self) -> str:
        return self._pending_request_sent_panel.object.title

    @property
    @allure.step('Get title of list with received pending requests')
    def pending_request_received_list_title(self) -> str:
        return self._pending_request_received_panel.object.title

    @property
    @allure.step('Get title of list with contacts')
    def contacts_list_title(self) -> str:
        return self._contacts_panel.object.title

    @property
    @allure.step('Get title of no friends item')
    def no_friends_item_text(self) -> str:
        return self._no_friends_item.object.text

    @allure.step('Open pending requests tab')
    def open_pending_requests(self):
        self._pending_request_tab.wait_until_appears(timeout_msec=10000).click()
        return self

    @allure.step('Open contacts tab')
    def open_contacts(self):
        self._contacts_tab.click()
        return self

    @allure.step('Open blocked tab')
    def open_blocked(self):
        self._blocked_tab.click()
        return self

    @allure.step('Open contacts request form')
    def open_contact_request_form(self) -> SendContactRequest:
        self._contact_request_button.click()
        return SendContactRequest().wait_until_appears()

    @allure.step('Open contacts request form')
    def send_contacts_request(self):
        SettingsLeftPanel().open_messaging_settings().open_contacts_settings().open_contact_request_form()

    @allure.step('Accept contact request')
    def find_contact_in_list(
            self, contact: str, timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        started_at = time.monotonic()
        request = None
        while request is None:
            requests = self.contact_items
            for _request in requests:
                if _request.contact == contact:
                    request = _request
            assert time.monotonic() - started_at < timeout_sec, f'Contact: {contact} not found in {requests}'
        return request

    @allure.step('Accept contact request')
    def accept_contact_request(self, contact: str,
                               timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC) -> MessagesScreen:
        self.open_pending_requests()
        request = self.find_contact_in_list(contact, timeout_sec)
        return request.accept()

    @allure.step('Reject contact request')
    def reject_contact_request(
            self, contact: str, timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        self.open_pending_requests()
        request = self.find_contact_in_list(contact, timeout_sec)
        request.reject()

    @allure.step('Open thee dots menu for contact')
    def open_more_options_popup(
            self, contact: str, timeout_sec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC):
        request = self.find_contact_in_list(contact, timeout_sec)
        request.open_more_options_popup()
        return self

    @allure.step('Verify identity')
    def verify_identity(self):
        self._verify_identity_item.click()
        return VerifyIdentityPopup().wait_until_appears()

    @allure.step('Get visibility state of respond to id request item')
    def is_respond_to_id_request_visible(self) -> bool:
        return self._respond_to_id_request_item.is_visible

    @allure.step('Respond to ID request')
    def respond_to_id_request(self):
        self._respond_to_id_request_item.click()
        return RespondToIDRequestPopup().wait_until_appears()

    @allure.step('Unblock user')
    def unblock_user(self):
        self._unblock_item.click()
        return UnblockUserPopup().wait_until_appears()

    @allure.step('Block user')
    def block_user(self):
        self._block_item.click()
        return BlockUserPopup().wait_until_appears()

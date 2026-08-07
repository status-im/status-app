import pathlib
import re
import time
import typing
from typing import List

import allure

import configs
import driver
from constants.messaging import Sticker
from driver.objects_access import (
    find_descendant_by_object_name,
    is_descendant_of,
    item_is_visible,
    walk_children,
)
from gui.components.community.pinned_messages_popup import PinnedMessagesPopup
from gui.components.context_menu import ContextMenu
from gui.components.delete_popup import ConfirmationMessagePopup
from gui.components.emoji_popup import EmojiPopup
from gui.components.messaging.clear_chat_history_popup import ClearChatHistoryPopup
from gui.components.messaging.close_chat_popup import CloseChatPopup
from gui.components.messaging.edit_group_name_and_image_popup import EditGroupNameAndImagePopup
from gui.components.messaging.leave_group_popup import LeaveGroupPopup
from gui.components.messaging.link_preview_options_popup import LinkPreviewOptionsPopup
from gui.components.messaging.message_context_menu_popup import MessageContextMenuPopup
from gui.components.settings.send_contact_request_popup import SendContactRequestFromProfile
from gui.components.wallet.send_popup import SendPopup
from gui.elements.button import Button
from gui.elements.list import List
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import messaging_names, communities_names
from gui.screens.community import CommunityScreen, BannedCommunityScreen
from helpers.chat_helper import message_plain_text, skip_message_backup_popup_if_visible
from scripts.tools.image import Image
from scripts.utils.generators import random_sticker


def _find_named_descendant(parent, object_name: str):
    try:
        descendant = find_descendant_by_object_name(parent, object_name)
        if descendant is not None:
            return descendant
    except (LookupError, RuntimeError, AttributeError):
        pass
    try:
        candidates = driver.findAllObjects({'objectName': object_name})
    except (LookupError, RuntimeError, AttributeError):
        return None
    return next(
        (
            candidate for candidate in candidates
            if is_descendant_of(parent, candidate)
        ),
        None,
    )


class LeftPanel(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_contactColumnLoader_Loader)
        self._start_chat_button = Button(messaging_names.mainWindow_startChatButton_StatusIconTabButton)
        self._search_text_edit = TextEdit(messaging_names.mainWindow_search_edit_TextEdit)
        self._scroll = Scroll(messaging_names.mainWindow_scrollView_StatusScrollView)
        self._chats_list = List(messaging_names.chatList_ListView)
        self._chat_list_item = QObject(messaging_names.scrollView_StatusChatListItem)
        self._chats_scroll = QObject(messaging_names.mainWindow_scrollView_StatusScrollView)

    @property
    @allure.step('Get chats by chats list')
    def get_chats_names(self) -> typing.List[str]:
        chats_list = []
        for child in walk_children(driver.waitForObjectExists(self._chats_list.real_name)):
            if getattr(child, 'id', '') == 'statusChatListItem':
                chats_list.append(str(child.objectName))
        return chats_list

    @allure.step('Click chat item')
    def click_chat_by_name(self, chat_name: str, attempts: int = 4):
        self._chat_list_item.real_name['objectName'] = chat_name
        
        for attempt in range(1, attempts + 1):
            self._chat_list_item.wait_until_appears()
            self._chat_list_item.click()
            skip_message_backup_popup_if_visible()
            try:
                return ChatView().wait_until_appears()
            except Exception as e:
                if attempt < attempts:
                    continue
                else:
                    raise Exception(f"Failed to open ChatView after {attempts} attempts: {e}")

    @allure.step('Click start chat button')
    def start_chat(self):
        self._start_chat_button.click(x=1, y=1)
        return CreateChatView()

    @allure.step('Open context menu group chat')
    def _open_context_menu_for_chat(self, chat_name: str) -> ContextMenu:
        self._chat_list_item.real_name['objectName'] = chat_name
        self._chat_list_item.right_click()
        return ContextMenu().wait_until_appears()

    @allure.step('Open leave popup')
    def open_leave_group_popup(self, chat_name: str, attempt: int = 2) -> LeaveGroupPopup:
        try:
            self._open_context_menu_for_chat(chat_name).select('Leave group')
            return LeaveGroupPopup().wait_until_appears()
        except Exception as ex:
            if attempt:
                return self.open_leave_group_popup(chat_name, attempt - 1)
            else:
                raise ex


class ToolBar(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_statusToolBar_StatusToolBar)
        self.pinned_message_tooltip = QObject(
            communities_names.statusToolBar_StatusChatInfo_pinText_TruncatedTextWithTooltip)
        self.confirm_button = Button(messaging_names.statusToolBar_Confirm_StatusButton)
        self.status_button = Button(messaging_names.statusToolBar_Cancel_StatusButton)
        self.contact_tag = QObject(messaging_names.statusToolBar_StatusTagItem)


    @allure.step('Remove member by clicking close icon on member tag')
    def click_contact_close_icon(self, member):
        for item in driver.findAllObjects(self.contact_tag.real_name):
            if str(getattr(item, 'text', '')) == str(member):
                for child in walk_children(item):
                    if getattr(child, 'objectName', '') == 'close-icon':
                        driver.mouseClick(child)
                        break

    @allure.step('Open Pinned messages popup')
    def open_pinned_messages_popup(self):
        self.pinned_message_tooltip.click()
        return PinnedMessagesPopup().wait_until_appears()


class Message:

    def __init__(self, obj):
        self.object = obj
        self.date: typing.Optional[str] = None
        self.time: typing.Optional[str] = None
        self.icon: typing.Optional[Image] = None
        self.from_user: typing.Optional[str] = None
        self.text: typing.Optional[str] = None
        self.delegate_button: typing.Optional[Button] = None
        self.reply_corner: typing.Optional[QObject] = None
        self.link_preview: typing.Optional[QObject] = None
        self.link_preview_title_object: typing.Optional[QObject] = None
        self.image_message: typing.Optional[QObject] = None
        self.banner_image: typing.Optional[QObject] = None
        self.community_invitation: dict = {}
        self.init_ui()

    def init_ui(self):
        try:
            for child in walk_children(self.object):
                try:
                    object_name = getattr(child, 'objectName', '')
                    child_id = getattr(child, 'id', '')

                    if object_name == 'StatusDateGroupLabel':
                        self.date = str(getattr(child, 'text', ''))
                    elif child_id == 'title':
                        self.community_invitation['name'] = str(getattr(child, 'text', ''))
                    elif child_id == 'description':
                        self.community_invitation['description'] = str(getattr(child, 'text', ''))
                    elif child_id == 'titleLayout':
                        self.link_preview_title_object = child
                    elif object_name == 'StatusTextMessage_chatText':
                        self.text = str(getattr(child, 'text', ''))
                    else:
                        match child_id:
                            case 'profileImage':
                                self.icon = Image(driver.objectMap.realName(child))
                            case 'primaryDisplayName':
                                self.from_user = str(getattr(child, 'text', ''))
                            case 'timestampText':
                                self.time = str(getattr(child, 'text', ''))
                            case 'chatText':
                                self.text = str(getattr(child, 'text', ''))
                            case 'replyCorner':
                                self.reply_corner = QObject(real_name=driver.objectMap.realName(child))
                            case 'delegate':
                                self.delegate_button = Button(real_name=driver.objectMap.realName(child))
                            case 'linksMessageView':
                                self.link_preview = QObject(real_name=driver.objectMap.realName(child))
                            case 'imageMessage':
                                self.image_message = child
                            case 'bannerImage':
                                self.banner_image = QObject(real_name=driver.objectMap.realName(child))
                except (AttributeError, RuntimeError, LookupError):
                    # Skip children that can't be accessed safely
                    continue
        except (RuntimeError, AttributeError, LookupError):
            # If walking children fails, continue with minimal initialization
            pass

        if self.text is None:
            chat_text = _find_named_descendant(self.object, 'StatusTextMessage_chatText')
            if chat_text is not None:
                self.text = str(getattr(chat_text, 'text', ''))

    def has_community_invite(self) -> bool:
        if self.community_link:
            return True
        if str(getattr(self.object, 'communityId', '') or ''):
            return True
        try:
            for child in walk_children(self.object):
                if str(getattr(child, 'communityId', '') or ''):
                    return True
                object_name = str(getattr(child, 'objectName', ''))
                if object_name in ('linkPreviewTitle', 'communityName', 'communityDescription'):
                    return True
        except (RuntimeError, AttributeError, LookupError):
            pass
        return False

    @property
    def community_link(self) -> typing.Optional[str]:
        match = re.search(r'https?://status\.app/c/[^\s<]+', message_plain_text(self))
        return match.group(0).rstrip('.,;:!?)]}') if match else None

    def activate_link(self, href: str) -> None:
        text_bubble = _find_named_descendant(self.object, 'StatusMessage_textMessage')
        if text_bubble is None:
            raise LookupError(f'Message text bubble was not found for link {href!r}')
        text_bubble.linkActivated(href)

    @allure.step('Open community invitation')
    def open_community_invitation(
            self,
            expected_link: str = None,
    ):
        community_link = self.community_link
        if expected_link is not None and community_link != expected_link.strip():
            raise AssertionError(
                'Received community URL does not match the copied URL: '
                f'expected={expected_link.strip()!r}, actual={community_link!r}'
            )

        if community_link is not None:
            self.activate_link(community_link)
        elif self.delegate_button is not None:
            self.delegate_button.click()
        else:
            raise LookupError('Community invitation has neither a link nor a clickable delegate')

        return CommunityScreen().wait_for_content_loaded()

    def open_banned_community_invitation(self):
        driver.waitFor(lambda: self.delegate_button.is_visible, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        self.delegate_button.click()
        return BannedCommunityScreen().wait_until_appears()

    @allure.step('Hover message')
    def hover_message(self):
        return MessageQuickActions(self)

    @property
    @allure.step('Get user name in pinned message details')
    def user_name_in_pinned_message(self) -> str:
        return str(self.delegate_button.object.pinnedBy)

    @property
    @allure.step('Get pinned message details')
    def pinned_details(self) -> typing.Tuple[str, str, str]:
        delegate = self.delegate_button.object
        return (
            str(delegate.pinnedMsgInfoText),
            str(delegate.pinnedBy),
            str(delegate.background.color.name),
        )

    @property
    def pinned_state(self) -> typing.Optional[bool]:
        try:
            return bool(getattr(self.object, 'pinnedMessage', False))
        except (RuntimeError, AttributeError):
            return None

    @property
    @allure.step('Get message pinned state')
    def message_is_pinned(self) -> bool:
        return self.pinned_state is True

    @property
    @allure.step('Whether message content is a sticker')
    def is_sticker_message(self) -> bool:
        return bool(getattr(self.object, 'isSticker', False))

    @allure.step('Get title of link preview')
    def get_link_preview_title(self) -> str:
        for child in walk_children(self.link_preview_title_object):
            if getattr(child, 'objectName', '') == 'linkPreviewTitle':
                return str(child.text)

    @allure.step('Get link domain from message')
    def get_link_domain(self) -> str:
        # Safely access linkData attribute which may not exist immediately
        link_data = getattr(self.delegate_button.object, 'linkData', None)
        if link_data is None:
            raise AttributeError('linkData is not available on message object yet')
        domain = getattr(link_data, 'domain', None)
        if domain is None:
            raise AttributeError('domain is not available in linkData')
        return str(domain)

    @allure.step('Open context menu for message')
    def open_context_menu_for_message(self):
        QObject(real_name=driver.objectMap.realName(self.object)).right_click()
        return MessageContextMenuPopup().wait_until_appears()

    @allure.step('Get emoji reactions pathes')
    def get_emoji_reactions_pathes(self):
        reactions_pathes = []
        try:
            for child in walk_children(self.object):
                try:
                    child_id = getattr(child, 'id', '')
                    if child_id == 'reactionDelegate':
                        # Search for StatusIcon inside reactionDelegate and extract emoji ID from icon path
                        try:
                            for item in walk_children(child):
                                try:
                                    icon_path = None
                                    if hasattr(item, 'icon'):
                                        icon_path = str(getattr(item, 'icon', ''))
                                    elif hasattr(item, 'source'):
                                        icon_path = str(getattr(item, 'source', ''))

                                    if icon_path:
                                        # Extract emoji ID from path like "qrc:/assets/twemoji/svg/1f600.svg"
                                        match = re.search(r'/([a-fA-F0-9]+)\.svg', icon_path)
                                        if match:
                                            reactions_pathes.append(match.group(1))
                                            break
                                except (AttributeError, RuntimeError, LookupError):
                                    # Skip items that can't be accessed safely
                                    continue
                        except (RuntimeError, AttributeError, LookupError):
                            # Skip reactionDelegate children if walking fails
                            continue
                except (AttributeError, RuntimeError, LookupError):
                    # Skip children that can't be accessed safely
                    continue
        except (RuntimeError, AttributeError, LookupError):
            # If walking children fails, return empty list
            pass

        return reactions_pathes


class ChatView(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_ChatColumnView)
        self._message_list_item = QObject(messaging_names.chatLogView_chatMessageViewDelegate_MessageView)
        self._deleted_message = QObject(messaging_names.chatMessageViewDelegate_deletedMessage_RowLayout)
        self._recent_messages_button = QObject(messaging_names.layout_recentMessagesButton_AnchorButton)

    @allure.step('Get messages')
    def messages(self, index: int) -> typing.List[Message]:
        _messages = []
        # message_list_item has different indexes if we run multiple instances, so we pass index
        if index is not None:
            self._message_list_item.real_name['index'] = index
        else:
            # When index is None, remove index from real_name so findAllObjects returns all list items
            self._message_list_item.real_name.pop('index', None)
        if self._recent_messages_button.is_visible:
            self._recent_messages_button.click()
        for item in driver.findAllObjects(self._message_list_item.real_name):
            if getattr(item, 'isMessage', True):
                _messages.append(Message(item))
        return _messages

    @allure.step('Open send modal from address link in message')
    def open_send_modal_from_link(self, text: str, index: int = 0):
        message = self.find_message_by_text(text, index)
        message.activate_link(f'//send-via-personal-chat//{text}')
        return SendPopup().wait_until_appears()

    @allure.step('Get deleted message state')
    def get_deleted_message_state(self):
        return self._deleted_message.exists

    def _find_message_by_text_once(
            self,
            message_text: str,
            index: typing.Optional[int],
    ) -> typing.Optional[Message]:
        indexes = (index, None) if index is not None else (None,)
        for current_index in indexes:
            for message in self.messages(current_index):
                if message_text in message_plain_text(message):
                    return message
        return None

    def find_message_by_text(
            self,
            message_text: str,
            index: typing.Optional[int] = None,
    ) -> Message:
        message = None
        last_error = None

        def message_found() -> bool:
            nonlocal last_error, message
            try:
                message = self._find_message_by_text_once(message_text, index)
                return message is not None
            except Exception as error:
                last_error = error
                return False

        timeout_msec = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
        if not driver.waitFor(message_found, timeout_msec):
            raise LookupError(
                f'Message not found within {timeout_msec} ms: {message_text!r}; '
                f'last error was {last_error!r}'
            )
        return message

    @allure.step('Wait for message pinned state')
    def wait_for_message_pinned(
            self,
            message_text: str,
            expected: bool,
            index: typing.Optional[int] = None,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ) -> Message:
        message = None
        last_error = None

        def state_matches() -> bool:
            nonlocal last_error, message
            try:
                message = self._find_message_by_text_once(message_text, index)
                return message is not None and message.pinned_state is expected
            except Exception as error:
                last_error = error
                return False

        state = 'pinned' if expected else 'unpinned'
        if not driver.waitFor(state_matches, timeout_msec):
            raise TimeoutError(
                f'Message {message_text!r} did not become {state} within {timeout_msec} ms; '
                f'last error was {last_error!r}'
            )
        return message

    @allure.step('Open community invitation')
    def click_community_invite(self, community: str, index: int) -> 'CommunityScreen':
        message = self.search_for_invitation(community, index)
        return message.open_community_invitation()

    def _find_community_invitation_message(self, index: typing.Optional[int] = 0) -> typing.Optional[Message]:
        for _message in self.messages(index):
            if _message.has_community_invite():
                return _message
        return None

    def _find_community_invitation_message_from_newest(self, start_index: int = 0) -> typing.Optional[Message]:
        for message_index in range(start_index, start_index + 20):
            message = self._find_community_invitation_message(message_index)
            if message:
                return message
        return None

    @allure.step('Open community invitation without relying on preview name')
    def click_community_invite_message(
            self,
            index: int = 0,
            expected_link: str = None,
    ) -> CommunityScreen:
        message = None

        def invitation_found() -> bool:
            nonlocal message
            message = self._find_community_invitation_message(index)
            if message is None:
                message = self._find_community_invitation_message_from_newest(0)
            return message is not None

        timeout_msec = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
        if not driver.waitFor(invitation_found, timeout_msec):
            raise LookupError(f'Community invitation was not found within {timeout_msec} ms')
        return message.open_community_invitation(expected_link=expected_link)

    @allure.step('Open banned community invitation')
    def open_banned_community(self, community, index) -> 'BannedCommunityScreen':
        message = self.search_for_invitation(community, index)
        return message.open_banned_community_invitation()

    def search_for_invitation(self, community, index):
        message = None
        started_at = time.monotonic()
        while message is None:
            for _message in self.messages(index):
                if _message.community_invitation.get('name', '') == community:
                    message = _message
                    break
            if time.monotonic() - started_at > 80:
                raise LookupError(f'Community invitation was not found')
        return message

    @allure.step('Wait until a sticker message appears in chat')
    def wait_until_sticker_message(
            self,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ) -> Message:
        found = []

        def sticker_visible():
            found.clear()
            for msg in self.messages(None):
                if msg.is_sticker_message:
                    found.append(msg)
                    return True
            return False

        assert driver.waitFor(sticker_visible, timeout_msec), 'Sticker message not found in chat'
        return found[0]


class CreateChatView(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_CreateChatView)
        self._confirm_button = Button(messaging_names.createChatView_confirmBtn)
        self._cancel_button = Button(messaging_names.mainWindow_Cancel_StatusButton)
        self._create_chat_contacts_list = List(messaging_names.createChatView_contactsList)
        self.recipient_input = QObject(messaging_names.createChatViewRecipientInput)

    @property
    @allure.step('Get contacts')
    def contact_names(self) -> typing.List[str]:
        user_names = [str(item.userName) for item in self._create_chat_contacts_list.items]
        return user_names

    @allure.step('Select contact in the list')
    def select_contact(self, contact: str):
        try:
            driver.waitFor(
                lambda: contact in self.contact_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC
            )
        except Exception:
            raise LookupError(f'Contact: {contact} was not found in {self.contact_names}')
        self._create_chat_contacts_list.select(contact, 'userName')

    @allure.step('Create chat by adding contacts from contact list')
    def create_chat(self, members):
        for member in members[0:]:
            time.sleep(0.2)
            self.select_contact(member)
        self._confirm_button.click()
        return ChatMessagesView().wait_until_appears()

    @allure.step('Create chat by sending a chat key')
    def create_chat_with_chat_key(self, chat_key):
        self.recipient_input.set_text_property(chat_key)
        return SendContactRequestFromProfile().wait_until_appears()


class ChatMessagesView(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_ChatMessagesView)
        self._group_chat_message_item = TextLabel(messaging_names.chatLogView_Item)
        self._group_name_label = TextLabel(messaging_names.statusChatInfoButton)
        self._more_button = Button(messaging_names.moreOptionsButton_StatusFlatRoundButton)
        self._edit_menu_item = QObject(messaging_names.edit_name_and_image_StatusMenuItem)
        self._leave_group_item = QObject(messaging_names.leave_group_StatusMenuItem)
        self._add_remove_item = QObject(messaging_names.add_remove_from_group_StatusMenuItem)
        self._clear_history_item = QObject(messaging_names.clear_History_StatusMenuItem)
        self._clear_group_chhat_history_item = QObject(messaging_names.clear_group_chat_history_item)
        self._close_chat_item = QObject(messaging_names.close_Chat_StatusMenuItem)
        self._chat_input = QObject(messaging_names.mainWindow_statusChatInput_StatusChatInput)
        self._message_input_area = QObject(messaging_names.inputScrollView_messageInputField_TextArea)
        self._message_field = TextEdit(messaging_names.inputScrollView_messageInputField_TextArea)
        self._emoji_button = Button(messaging_names.mainWindow_statusChatInputEmojiButton_StatusFlatRoundButton)
        self._image_button = Button(messaging_names.mainWindow_imageBtn_StatusFlatRoundButton)
        self._link_preview_title = QObject(messaging_names.mainWindow_linkPreviewTitleText_StatusBaseText)
        self._link_preview_preview_subtitle = QObject(messaging_names.mainWindow_linkPreviewSubtitleText_StatusBaseText)
        self._link_preview_show_preview = QObject(messaging_names.mainWindow_titleText_StatusBaseText)
        self._link_preview_show_description = QObject(messaging_names.mainWindow_subtitleText_StatusBaseText)
        self._link_preview_card = QObject(messaging_names.mainWindow_settingsCard_LinkPreviewSettingsCard)
        self._options_combobox = QObject(messaging_names.mainWindow_optionsComboBox_ComboBox)
        self._close_preview_button = QObject(messaging_names.mainWindow_closeLinkPreviewButton_StatusFlatRoundButton)
        self._send_message_button = Button(messaging_names.mainWindow_statusChatInputSendButton)

    @property
    @allure.step('Get group name')
    def group_name(self) -> str:
        return self._group_name_label.text

    @allure.step('Get group welcome message')
    def group_welcome_message(self) -> str:
        for delegate in walk_children(self._group_chat_message_item.wait_until_appears().object):
            if getattr(delegate, 'id', '') == 'msgDelegate':
                for item in walk_children(delegate):
                    if getattr(item, 'id', '') == 'descText':
                        return str(item.text)

    @property
    @allure.step('Get gray text from message area')
    def gray_text_from_message_area(self) -> str:
        return driver.waitForObjectExists(self._message_input_area.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).placeholderText

    @property
    @allure.step('Get enabled state of message area')
    def is_message_area_enabled(self) -> bool:
        return driver.waitForObjectExists(self._message_input_area.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @allure.step('Click more options button')
    def open_more_options(self):
        self._more_button.click()

    @allure.step('Choose edit group name option')
    def open_edit_group_name_form(self):
        self.open_more_options()
        self._edit_menu_item.wait_until_appears().click()
        return EditGroupNameAndImagePopup().wait_until_appears()

    @allure.step('Choose leave group option')
    def leave_group(self):
        self.open_more_options()
        self._leave_group_item.wait_until_appears().click()
        return LeaveGroupPopup().wait_until_appears()

    @allure.step('Send message to group chat')
    def send_message_to_group_chat(self, message: str):
        self._message_field.click()
        self.type_message(message)
        self.confirm_sending_message()

    @allure.step('Type text to message field')
    def type_message(self, message: str):
        self._message_field.set_text_property(message)

    @allure.step('Confirm sending message')
    def confirm_sending_message(self):
        assert driver.waitFor(
            lambda: self._send_message_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send button stayed disabled after composing message'
        self._send_message_button.click()

    @allure.step('Click options combobox')
    def click_options(self):
        self._options_combobox.click()
        return LinkPreviewOptionsPopup().wait_until_appears()

    @allure.step('Close link preview popup by clicking preview bubble area')
    def close_link_preview_popup(self):
        self._link_preview_card.click()
        return self

    @allure.step('Get text of title of link preview bubble')
    def get_link_preview_bubble_title(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> str:
        def _ready():
            try:
                str(self._link_preview_title.object.text); return True
            except (RuntimeError, AttributeError, LookupError):
                return False

        driver.waitFor(_ready, timeout_msec)
        return str(self._link_preview_title.object.text)

    @allure.step('Get text of description of link preview bubble')
    def get_link_preview_bubble_description(self) -> str:
        return str(self._link_preview_preview_subtitle.object.text)

    @allure.step('Get text of title of show link preview bubble')
    def get_show_link_preview_bubble_title(self) -> str:
        return str(self._link_preview_show_preview.object.text)

    @allure.step('Get text of description of show link preview bubble')
    def get_show_link_preview_bubble_description(self) -> str:
        return str(self._link_preview_show_description.object.text)

    @allure.step('Get close button visibility state')
    def does_close_button_exist(self) -> bool:
        return self._close_preview_button.is_visible

    @allure.step('Send sticker to chat')
    def send_sticker_to_chat(self, sticker: Sticker = None, url: str = ''):
        sticker = sticker or random_sticker()
        self._chat_input.object.selectStickerForTest(sticker.hash, sticker.pack_id, url)

    @allure.step('Send emoji to chat')
    def send_emoji_to_chat(self, emoji: str):
        self._emoji_button.click()
        EmojiPopup().wait_until_appears().select(emoji)
        self.send_message()

    @allure.step('Send image to chat')
    def send_image_to_chat(self, path_or_base64):
        self.choose_image(path_or_base64)
        self.send_message()

    @allure.step('Choose image')
    def choose_image(self, path_or_base64):
        # check if input is base64 or path
        if isinstance(path_or_base64, str) and path_or_base64.startswith('data:image/'):
            self._chat_input.object.selectImageString(path_or_base64)  # if base64, pass as is
        else:
            fileuri = pathlib.Path(str(path_or_base64)).as_uri()  # if path, convert to path uri
            self._chat_input.object.selectImageString(fileuri)

    @allure.step('Confirm sending message')
    def send_message(self):
        assert driver.waitFor(
            lambda: self._send_message_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send button stayed disabled'
        self._send_message_button.click()

    @allure.step('Remove member from chat')
    def remove_member_from_chat(self, member):
        self.open_more_options()
        self._add_remove_item.wait_until_appears().click()
        tool_bar = ToolBar().wait_until_appears()
        tool_bar.click_contact_close_icon(member)
        tool_bar.confirm_button.wait_until_appears().click()

    @allure.step('Clear chat history option')
    def clear_history(self):
        self.open_more_options()
        self._clear_history_item.wait_until_appears().click()
        clear_history_popup = ClearChatHistoryPopup().wait_until_appears()
        clear_history_popup.confirm_clearing_chat()

    @allure.step('Clear group chat history option')
    def clear_group_chat_history(self):
        self.open_more_options()
        self._clear_group_chhat_history_item.wait_until_appears().click()
        clear_history_popup = ClearChatHistoryPopup().wait_until_appears()
        clear_history_popup.confirm_clearing_chat()

    @allure.step('Close chat')
    def close_chat(self):
        self.open_more_options()
        self._close_chat_item.wait_until_appears().click()
        CloseChatPopup().wait_until_appears().confirm_closing_chat()


class MessageQuickActions:

    _OBJECT_NAME_BY_ACTION = {
        'edit': 'editMessageButton',
        'delete': 'chatDeleteMessageButton',
        'reply': 'replyToMessageButton',
        'pin': 'MessageView_toggleMessagePin',
    }

    def __init__(self, message: Message):
        self._message = message
        self._reply_panel = QObject(messaging_names.mainWindow_replyPanel_StatusChatInputReplyPanel)
        self._edit_message_input = QObject(messaging_names.mainWindow_statusChatInput_StatusChatInput)
        self._edit_message_field = TextEdit(messaging_names.inputScrollView_messageInputField_TextArea)
        self._message_input_area = TextEdit(messaging_names.inputScrollView_messageInputField_TextArea)
        self._send_message_button = Button(messaging_names.mainWindow_statusChatInputSendButton)

    def _refresh_action(self, action: str) -> Button:
        if self._message.delegate_button is None:
            raise LookupError('Message delegate not found; cannot open quick actions')

        button = None
        last_error = None

        def action_ready():
            nonlocal button, last_error
            try:
                self._message.delegate_button.hover()
                item = _find_named_descendant(
                    self._message.object,
                    self._OBJECT_NAME_BY_ACTION[action],
                )
                if (
                        item is None
                        or not item_is_visible(item)
                        or not bool(getattr(item, 'enabled', False))
                ):
                    return False
                button = Button(real_name=driver.objectMap.realName(item))
                return True
            except Exception as error:
                last_error = error
                return False

        timeout_msec = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
        if not driver.waitFor(action_ready, timeout_msec):
            raise TimeoutError(
                f'{action} quick action was not ready within {timeout_msec} ms; '
                f'last error was {last_error!r}'
            )
        return button

    def _toggle_pin(self):
        self._refresh_action('pin').object.clicked(0)

    @allure.step('Click pin button')
    def pin_message(self):
        self._toggle_pin()

    @allure.step('Click unpin button')
    def unpin_message(self):
        self._toggle_pin()

    @allure.step('Edit message and save changes')
    def edit_message(self, text: str):
        self._refresh_action('edit').object.clicked(0)
        self._edit_message_input.wait_until_appears()
        self._edit_message_field.set_text_property(text)
        self._send_message_button.wait_until_enabled().click()

    @allure.step('Delete message')
    def delete_message(self):
        self._refresh_action('delete').object.clicked(0)
        ConfirmationMessagePopup().wait_until_appears().delete_button.click()

    @allure.step('Reply to own message')
    def reply_own_message(self, text: str):
        self._refresh_action('reply').object.clicked(0)
        assert self._reply_panel.exists
        self._message_input_area.set_text_property(text)
        assert driver.waitFor(
            lambda: self._send_message_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send button stayed disabled after reply text'
        self._send_message_button.click()

    @allure.step('Delete button is visible')
    def is_delete_button_visible(self) -> bool:
        try:
            self._refresh_action('delete')
        except (LookupError, TimeoutError):
            return False
        return True


class Members(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_userListPanel_StatusListView)
        self._member_item = QObject(messaging_names.groupUserListPanel_StatusMemberListItem)

    @property
    @allure.step('Get group members')
    def members(self) -> typing.List[str]:
        return [str(member.userName) for member in driver.findAllObjects(self._member_item.real_name)]


class MessagesScreen(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_chatView_ChatView)
        self.left_panel = LeftPanel()
        self.tool_bar = ToolBar()
        self.chat = ChatView()
        self.right_panel = Members()
        self.group_chat = ChatMessagesView()

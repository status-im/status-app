import typing

import allure

import driver
from gui.components.community.pinned_messages_popup import PinnedMessagesPopup
from gui.components.context_menu import ContextMenu
from gui.components.messaging.leave_group_popup import LeaveGroupPopup
from gui.elements.button import Button
from gui.elements.list import List
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import communities_names, messaging_names
from driver.objects_access import walk_children
from helpers.chat_helper import skip_message_backup_popup_if_visible


class LeftPanel(QObject):

    def __init__(self):
        super().__init__(messaging_names.contactsColumnView_chatList)
        self._start_chat_button = Button(messaging_names.mainWindow_startChatButton_StatusIconTabButton)
        self._search_text_edit = TextEdit(messaging_names.mainWindow_search_edit_TextEdit)
        self._chats_list = List(messaging_names.chatList_ListView)
        self._chat_list_item = QObject(dict(messaging_names.chatList_StatusChatListItem))
        self._chats_scroll = QObject(messaging_names.chatList_ListView)

    @property
    @allure.step('Get chats by chats list')
    def get_chats_names(self) -> typing.List[str]:
        self._chat_list_item.real_name.pop('objectName', None)
        chats_list = []
        for item in driver.findAllObjects(self._chat_list_item.real_name):
            name = str(getattr(item, 'objectName', ''))
            if name:
                chats_list.append(name)
        return chats_list

    @allure.step('Click chat item')
    def click_chat_by_name(self, chat_name: str, attempts: int = 4):
        self._chat_list_item.real_name['objectName'] = chat_name
        
        for attempt in range(1, attempts + 1):
            self._chat_list_item.wait_until_appears()
            self._chat_list_item.click()
            skip_message_backup_popup_if_visible()
            try:
                from gui.screens.messages.chat import ChatView
                return ChatView().wait_until_appears()
            except Exception as e:
                if attempt < attempts:
                    continue
                else:
                    raise Exception(f"Failed to open ChatView after {attempts} attempts: {e}")

    @allure.step('Click start chat button')
    def start_chat(self):
        self.wait_until_appears()
        self._start_chat_button.click(x=1, y=1)
        from gui.screens.messages.chat import CreateChatView
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


class Members(QObject):

    def __init__(self):
        super().__init__(messaging_names.mainWindow_userListPanel_StatusListView)
        self._member_item = QObject(messaging_names.groupUserListPanel_StatusMemberListItem)

    @property
    @allure.step('Get group members')
    def members(self) -> typing.List[str]:
        return [str(member.userName) for member in driver.findAllObjects(self._member_item.real_name)]

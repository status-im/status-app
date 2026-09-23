import configs
from gui.elements.object import QObject
from gui.objects_map import messaging_names
from gui.screens.messages.chat import ChatMessagesView, ChatView
from gui.screens.messages.panels import LeftPanel, Members, ToolBar


class MessagesScreen(QObject):

    def __init__(self):
        super().__init__(messaging_names.contactsColumnView_chatList)
        self.left_panel = LeftPanel()
        self.tool_bar = ToolBar()
        self.chat = ChatView()
        self.right_panel = Members()
        self.group_chat = ChatMessagesView()

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC, check_interval=0.5):
        super().wait_until_appears(timeout_msec, check_interval)
        self.chat.wait_until_appears(timeout_msec, check_interval)
        return self

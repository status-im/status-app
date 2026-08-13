import QtQuick
import QtTest

import utils

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 ChatHeaderContentView "more options" menu
 =========================================
 The header's ChatContextMenuView (objectName moreOptionsContextMenu) was an
 eager inline child — a full menu tree built at section load for every open
 chat, needed only after the More button is clicked.

 Flows:
 - no interaction        → menu not instantiated (perf intent, test 1)
 - More button clicked   → menu instantiated, configured via openHandler
   from the chat content module, and shown (test 2)
*/
Item {
    id: root

    width: 700
    height: 100

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property string name: "Contact 1"
            readonly property string description: ""
            readonly property string emoji: ""
            readonly property string color: "#4360DF"
            readonly property string icon: ""
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool muted: false
            readonly property int position: 0
            readonly property bool hideIfPermissionsNotMet: false
            readonly property bool belongsToCommunity: false
            readonly property bool isUsersListAvailable: true
            readonly property bool canView: true
            readonly property bool canPost: true
        }

        function amIChatAdmin() { return false }
    }

    ChatStores.RootStore {
        id: rootStoreMock

        function currentChatContentModule() { return chatContentModuleMock }
    }

    ChatHeaderContentView {
        id: header
        width: parent.width
        rootStore: rootStoreMock
    }

    TestCase {
        name: "ChatHeaderMenu"
        when: windowShown

        // INTENT (perf): the More menu must not be instantiated at load
        function test_01_menuNotBuiltAtLoad() {
            wait(200)
            verify(!findChild(header, "moreOptionsContextMenu"),
                   "the More menu must not exist before the button is clicked")
        }

        // clicking More instantiates and opens the configured menu
        function test_02_moreButtonOpensMenu() {
            const button = findChild(header, "chatToolbarMoreOptionsButton")
            verify(!!button)
            mouseClick(button)

            tryVerify(() => {
                const menu = findChild(header, "moreOptionsContextMenu")
                return !!menu && menu.opened
            }, 3000, "More must open the context menu")

            const menu = findChild(header, "moreOptionsContextMenu")
            compare(menu.chatId, "chat-1")
            menu.close()
            tryVerify(() => !menu.opened)
        }
    }
}

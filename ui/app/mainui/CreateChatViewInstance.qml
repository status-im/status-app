import QtQuick

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

// Loaded by URL (see AppMain), so CreateChatView is not part of AppMain's type closure
CreateChatView {
    id: root

    required property var chatContactsStore
    required property var chatCurrencyStore
    required property var chatCommunityTokensStore
    required property bool openCreateChat
    required property real defaultWidth
    required property real maxWidth

    width: Math.min(Math.max(implicitWidth, root.defaultWidth), root.maxWidth)

    rootStore: ChatStores.RootStore {
        contactsStore: root.chatContactsStore
        currencyStore: root.chatCurrencyStore
        communityTokensStore: root.chatCommunityTokensStore
        openCreateChat: root.openCreateChat
        isChatSectionModule: true
    }
}

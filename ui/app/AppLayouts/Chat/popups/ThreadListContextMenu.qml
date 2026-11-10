import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Chat.stores

ThreadContextMenu {
    id: root

    required property var sectionModule
    property string parentChatId
    property string threadName
    property var messageModule
    readonly property bool canManage: messageStore.canManageThreadById(root.threadId)

    signal renameThreadRequested(string threadId, string threadName, string parentChatId)

    isMobile: SQUtils.Utils.isMobile
    followed: d.followed
    muted: false
    pinned: false
    pinEnabled: false
    threadLinkToCopyShare: ""
    deleteEnabled: root.canManage && !messageStore.threadDeletePending && !messageStore.threadEditPending
    editEnabled: root.deleteEnabled

    openHandler: function(id) {
        root.threadId = ""
        root.parentChatId = ""
        root.threadName = ""
        root.messageModule = null
        try {
            const item = JSON.parse(root.sectionModule.getItemAsJson(id))
            if (item.error || !item.isThread || !item.parentChatId) {
                console.error("Cannot open thread menu:", id, item.error)
                root.close()
                return
            }
            root.threadId = item.itemId
            root.parentChatId = item.parentChatId
            root.threadName = item.name
            d.followed = !!item.followed
            root.sectionModule.prepareChatContentModuleForChatId(root.parentChatId)
            const contentModule = root.sectionModule.getChatContentModule()
            if (!contentModule) {
                console.error("Cannot open thread menu: missing parent chat module", root.parentChatId)
                root.close()
                return
            }
            root.messageModule = contentModule.messagesModule
        } catch (e) {
            console.error("Cannot open thread menu:", id, e)
            root.close()
        }
    }

    onMarkAsReadRequested: root.sectionModule.markAllMessagesRead(root.parentChatId, root.threadId)
    onFollowRequested: messageStore.setThreadFollowedById(root.threadId, true)
    onUnfollowRequested: messageStore.setThreadFollowedById(root.threadId, false)
    onDeleteRequested: messageStore.deleteThreadById(root.threadId)
    onEditNameRequested: root.renameThreadRequested(root.threadId, root.threadName, root.parentChatId)

    QtObject {
        id: d
        property bool followed: false
    }

    MessageStore {
        id: messageStore
        objectName: "threadListMessageStore"
        messageModule: root.messageModule
    }
}

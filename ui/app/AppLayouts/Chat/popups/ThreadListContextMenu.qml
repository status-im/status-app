import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Chat.stores

ThreadContextMenu {
    id: root

    required property var sectionModule
    property string parentChatId
    property string threadName
    property var messageModule
    property bool canManage: false

    signal renameThreadRequested(string threadId, string threadName, string parentChatId)

    isMobile: SQUtils.Utils.isMobile
    followed: false
    muted: false
    pinned: false
    pinEnabled: false
    threadLinkToCopyShare: ""
    deleteEnabled: root.canManage && !messageStore.threadDeletePending && !messageStore.threadEditPending
    editEnabled: root.deleteEnabled

    openHandler: function(id) {
        root.canManage = false
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
            root.sectionModule.prepareChatContentModuleForChatId(root.parentChatId)
            const contentModule = root.sectionModule.getChatContentModule()
            if (!contentModule) {
                console.error("Cannot open thread menu: missing parent chat module", root.parentChatId)
                root.close()
                return
            }
            root.messageModule = contentModule.messagesModule
            root.canManage = messageStore.canManageThreadById(root.threadId)
        } catch (e) {
            console.error("Cannot open thread menu:", id, e)
            root.close()
        }
    }

    onMarkAsReadRequested: root.sectionModule.markAllMessagesRead(root.parentChatId, root.threadId)
    onDeleteRequested: messageStore.deleteThreadById(root.threadId)
    onEditNameRequested: root.renameThreadRequested(root.threadId, root.threadName, root.parentChatId)

    MessageStore {
        id: messageStore
        messageModule: root.messageModule
    }
}

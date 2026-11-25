import QtQuick

import QtModelsToolkit

import StatusQ.Core.Utils as SQUtils

ThreadContextMenu {
    id: root

    required property var sectionModule
    property var threadsModel: null
    property string parentChatId
    property string threadName
    property var canManageThread
    property bool threadChangesPending: false
    property bool canManage: false

    signal renameThreadRequested(string threadId, string threadName, string parentChatId)

    isMobile: SQUtils.Utils.isMobile
    followed: d.followed
    muted: threadEntry.item?.muted ?? false
    pinned: false
    pinEnabled: false
    threadLinkToCopyShare: ""
    deleteEnabled: root.canManage && !root.threadChangesPending
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
            d.followed = !!item.followed
            root.canManage = root.canManageThread?.(root.threadId, root.parentChatId) ?? false
        } catch (e) {
            console.error("Cannot open thread menu:", id, e)
            root.close()
        }
    }

    onMarkAsReadRequested: root.sectionModule.markAllMessagesRead(root.parentChatId, root.threadId)
    onEditNameRequested: root.renameThreadRequested(root.threadId, root.threadName, root.parentChatId)

    ModelEntry {
        id: threadEntry
        sourceModel: root.threadsModel
        key: "key"
        value: root.threadId
    }

    QtObject {
        id: d
        property bool followed: false
    }
}

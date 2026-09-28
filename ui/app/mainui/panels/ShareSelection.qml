import QtQml

import StatusQ.Core.Utils

/**
  * The share selection (see CONTEXT.md): the set of destination chat ids the
  * user ticked. Unordered; consumers order it by their own model. State
  * changes only through the methods. Holds at most maxCount ids: toggling a
  * new one in while full is refused.
  */
QtObject {
    id: root

    property var chatIds: []
    property int maxCount: 5

    readonly property int count: root.chatIds.length
    readonly property bool isFull: root.count >= root.maxCount

    signal changed()

    function contains(chatId) {
        return root.chatIds.indexOf(chatId) !== -1
    }

    function toggle(chatId) {
        const ids = root.chatIds.slice()
        const index = ids.indexOf(chatId)
        if (index === -1) {
            if (root.isFull)
                return
            ids.push(chatId)
        } else {
            ids.splice(index, 1)
        }
        root.chatIds = ids
        root.changed()
    }

    function clear() {
        if (root.chatIds.length === 0)
            return
        root.chatIds = []
        root.changed()
    }

    function retainOnly(model) {
        const kept = root.chatIds.filter(id => ModelUtils.contains(model, "chatId", id))
        if (kept.length === root.chatIds.length)
            return
        root.chatIds = kept
        root.changed()
    }
}

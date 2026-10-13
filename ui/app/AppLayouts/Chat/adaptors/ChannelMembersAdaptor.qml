import QtQml

import StatusQ.Core.Utils

import QtModelsToolkit

// Narrows a community roster to the members of one channel. A token-gated
// channel keeps only its member set, swapped in one step whenever the roster
// reports a change to it; any other channel shows the whole roster.
QObject {
    id: root

    // Community roster: a `pubKey` role, plus isGatedChannel(chatId),
    // getChannelMemberKeys(chatId) (a JSON array of keys) and the
    // channelMembersChanged(chatId) signal.
    property var rosterModel
    property string chatId

    // output model
    readonly property var model: d.gated ? keySetFilter : root.rosterModel

    KeySetFilterModel {
        id: keySetFilter

        sourceModel: d.gated ? root.rosterModel : null
        keyRoleName: "pubKey"
        keys: d.keys
    }

    QtObject {
        id: d

        property bool gated
        property var keys: []

        function refresh() {
            const roster = root.rosterModel
            const gatedNow = !!roster && !!root.chatId && roster.isGatedChannel(root.chatId)
            keys = gatedNow ? JSON.parse(roster.getChannelMemberKeys(root.chatId)) : []
            gated = gatedNow
        }
    }

    Connections {
        target: root.rosterModel ?? null
        ignoreUnknownSignals: true

        function onChannelMembersChanged(chatId) {
            if (chatId === root.chatId)
                d.refresh()
        }
    }

    onRosterModelChanged: d.refresh()
    onChatIdChanged: d.refresh()
    Component.onCompleted: d.refresh()
}

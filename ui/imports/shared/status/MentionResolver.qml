import QtQuick

import StatusQ.Core.Utils

// Resolves chat mention pub keys to display names for the client-side renderer/editor.
//
// Builds a reactive { pubKey: displayName } map from a source model (with pub-key and
// display-name roles), always including the "everyone" system tag (0x00001). This is the
// single seam used by ChatTextView (rendering) and ChatTextArea.loadText (editing) to turn
// the raw "@0x…" mentions in a message into display names — replacing the status-go/Nim
// name resolution.
QObject {
    id: root

    // Source of mentionable users; must expose a pub-key role and a display-name role.
    property var sourceModel: null
    property string pubKeyRole: "pubKey"
    property string nameRole: "name"

    // pubKey -> display name. The "everyone" system tag is always present; an unknown pub key
    // is simply absent (the renderer/editor then falls back to the raw key).
    readonly property var map: {
        connections._revision // re-evaluate when the model's contents change
        const result = { "0x00001": "everyone" }
        if (root.sourceModel) {
            ModelUtils.forEach(root.sourceModel, item => {
                const pubKey = item[root.pubKeyRole]
                if (pubKey)
                    result[pubKey] = item[root.nameRole]
            })
        }
        return result
    }


    Connections {
        id: connections

        target: root.sourceModel
        ignoreUnknownSignals: true

        property int _revision: 0

        function onModelReset() { _revision++ }
        function onDataChanged() { _revision++ }
        function onRowsInserted() { _revision++ }
        function onRowsRemoved() { _revision++ }
    }
}

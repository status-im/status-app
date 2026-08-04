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

    // When false, the map is frozen: source-model changes are still tracked but not applied.
    // Setting it back to true rebuilds the map once, and only if the model changed meanwhile.
    property bool enabled: true

    // pubKey -> display name. The "everyone" system tag is always present; an unknown pub key
    // is simply absent (the renderer/editor then falls back to the raw key).
    readonly property var map: {
        d.appliedRevision // re-evaluate only when the applied revision advances
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

    QtObject {
        id: d

        // Monotonic count of relevant source-model changes.
        property int sourceRevision: 0
        // The source revision the map currently reflects. Tracks sourceRevision only while
        // enabled (frozen otherwise), so re-enabling rebuilds the map if it fell behind.
        property int appliedRevision: 0
    }

    // Apply the latest source revision while enabled; freeze it (RestoreNone) while disabled so
    // re-enabling re-samples and rebuilds only when sourceRevision advanced in the meantime.
    Binding {
        target: d
        property: "appliedRevision"
        value: d.sourceRevision
        when: root.enabled
        restoreMode: Binding.RestoreNone
    }

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true

        function onModelReset() { d.sourceRevision++ }
        // Only rebuild the map when the display-name role actually changed. An empty `roles`
        // list means "all roles" (Qt convention); a negative lookup (role/model not ready)
        // also rebuilds to be safe.
        function onDataChanged(topLeft, bottomRight, roles) {
            const nameRoleNum = ModelUtils.roleByName(root.sourceModel, root.nameRole)
            if (roles.length === 0 || nameRoleNum < 0 || roles.includes(nameRoleNum))
                d.sourceRevision++
        }
        function onRowsInserted() { d.sourceRevision++ }
        function onRowsRemoved() { d.sourceRevision++ }
    }
}

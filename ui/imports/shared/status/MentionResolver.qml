import QtQuick

import StatusQ
import StatusQ.Core.Utils

// Resolves chat mention pub keys to display names for the client-side renderer/editor.
//
// resolveFor(text) extracts the mentions present in a message text and resolves them
// against a source model (with pub-key and display-name roles), always resolving the
// "everyone" system tag (0x00001). This is the single seam used by ChatTextView
// (rendering) and ChatTextArea.loadText (editing) to turn the raw "@0x…" mentions in a
// message into display names — replacing the status-go/Nim name resolution.
//
// Cost scales with the mentions in the text — a regex scan plus one keyed model lookup
// per distinct unseen key (cached until the model changes) — never with the size of the
// source model. The result crosses into MarkdownUtils as a QVariantMap, so keeping it
// per-message also keeps that conversion small.
QObject {
    id: root

    // Source of mentionable users; must expose a pub-key role and a display-name role.
    property var sourceModel: null
    property string pubKeyRole: "pubKey"
    property string nameRole: "name"

    // When false, results are frozen: source-model changes are still tracked but not
    // applied. Setting it back to true catches up once, and only if the model changed
    // meanwhile.
    property bool enabled: true

    // { pubKey: displayName } for the mentions present in `text`. An unknown pub key is
    // simply absent (the renderer/editor then falls back to the raw key). Reads the
    // applied revision, so QML bindings over this call re-evaluate when tracked
    // source-model changes are applied.
    function resolveFor(text) {
        const revision = d.appliedRevision
        if (revision !== d.cacheRevision) {
            d.cache = ({})
            d.cacheRevision = revision
        }

        const result = {}
        if (!text)
            return result

        // Extraction follows the parser's wire grammar exactly
        const keys = MarkdownUtils.mentions(text)
        for (const pubKey of keys) {
            if (pubKey in result)
                continue

            let name = d.cache[pubKey]
            if (name === undefined) {
                if (pubKey === "0x00001")
                    name = "everyone"
                else if (root.sourceModel)
                    name = ModelUtils.getByKey(root.sourceModel, root.pubKeyRole, pubKey, root.nameRole)
                name = (name === undefined || name === null) ? null : name
                d.cache[pubKey] = name
            }
            if (name !== null)
                result[pubKey] = name
        }
        return result
    }

    QtObject {
        id: d

        // Per-revision resolution cache: pubKey -> displayName, or null for a key known
        // to be absent from the model.
        property var cache: ({})
        property int cacheRevision: 0

        // Monotonic count of relevant source-model changes.
        property int sourceRevision: 0
        // The source revision resolution currently reflects. Tracks sourceRevision only
        // while enabled (frozen otherwise), so re-enabling catches up if it fell behind.
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

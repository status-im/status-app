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
// A key the model does not know takes the name the message itself carries (status-go's
// `mentionedNames`), then falls back to `aliasProvider`, so a mention of somebody the
// local user has never heard of reads as a name or a generated 3-word alias rather than
// a raw key. A key left with only the alias (status-go also sends the alias for a person
// it has never seen) is handed to `contactInfoRequester` once, which is how the alias
// eventually becomes the real name. Resolving itself never calls into the backend.
//
// Cost scales with the mentions in the text: a parser scan plus one model lookup per
// distinct unseen key, cached until the model changes. A message without mentions never
// touches the model at all, which is what keeps a model as wide as the whole contact
// list affordable here — the per-key lookup itself is a row scan in C++. The result
// crosses into MarkdownUtils as a QVariantMap, so keeping it per-message also keeps that
// conversion small.
QObject {
    id: root

    // Source of mentionable users; must expose a pub-key role and a display-name role.
    property var sourceModel: null
    property string pubKeyRole: "pubKey"
    property string nameRole: "name"

    // Last resort for a key absent from the source model: (pubKey) -> name, expected to
    // be a store's generated-alias call. Asked on every miss: generating an alias takes
    // microseconds, so it is not worth a cache of its own. Without a provider an unknown
    // key stays unresolved and the renderer falls back to the raw key.
    property var aliasProvider: null

    // Notified once per key that only an alias can name: (pubKey) -> void, expected to be
    // a store's mailserver profile request. It is fire-and-forget: a successful answer
    // reaches the source model on its own and the name resolves on the next pass.
    property var contactInfoRequester: null

    // The local user, resolved to this live name ahead of the model and the message:
    // neither the contacts model nor a roster snapshot carries it fresh.
    property string selfPubKey
    property string selfName

    // When false, results are frozen: source-model changes are still tracked but not
    // applied. Setting it back to true catches up once, and only if the model changed
    // meanwhile.
    property bool enabled: true

    // { pubKey: displayName } for the mentions present in `text`. `knownNames` is the
    // message's own { pubKey: name } (a JSON string, as the message model's
    // `mentionedNames` role, or an object), used for keys the model cannot name. A pub
    // key nobody can name is simply absent (the renderer/editor then falls back to the
    // raw key). Reads the applied revision, so QML bindings over this call re-evaluate
    // when tracked source-model changes are applied.
    function resolveFor(text, knownNames) {
        // dependency only: the cache itself is reset by the revision's change handler, as
        // writing a property from inside the caller's binding is a binding loop
        d.appliedRevision

        const result = {}
        if (!text)
            return result

        // parsed on the first model miss only
        let known

        // Extraction follows the parser's wire grammar exactly
        const keys = MarkdownUtils.mentions(text)
        for (const pubKey of keys) {
            if (pubKey in result)
                continue

            if (root.selfPubKey && pubKey === root.selfPubKey && root.selfName) {
                result[pubKey] = root.selfName
                continue
            }

            let name = d.cache[pubKey]
            if (name === undefined) {
                if (pubKey === "0x00001")
                    name = "everyone"
                else if (root.sourceModel)
                    name = ModelUtils.getByKey(root.sourceModel, root.pubKeyRole, pubKey, root.nameRole)
                // an empty name is a miss too: the row exists but has nothing to show
                name = name || null
                d.cache[pubKey] = name
            }
            if (name === null) {
                if (known === undefined)
                    known = d.parseKnownNames(knownNames)
                const messageName = known[pubKey] || null
                // the alias is only worth computing to compare when somebody can be asked
                const alias = !messageName || root.contactInfoRequester ? d.aliasOf(pubKey) : null
                if (!messageName || messageName === alias)
                    d.requestInfoFor(pubKey)
                name = messageName || alias
            }
            if (name !== null)
                result[pubKey] = name
        }
        return result
    }

    QtObject {
        id: d

        // Per-revision resolution cache: pubKey -> displayName, or null for a key known
        // to be absent from the model. Filled in place, which notifies nothing.
        property var cache: ({})

        // Monotonic count of relevant source-model changes.
        property int sourceRevision: 0
        // The source revision resolution currently reflects. Tracks sourceRevision only
        // while enabled (frozen otherwise), so re-enabling catches up if it fell behind.
        property int appliedRevision: 0

        onAppliedRevisionChanged: cache = ({})

        // Keys already handed to the requester, so each costs at most one round trip per
        // resolver instance. A failed request is not retried here.
        property var requested: ({})

        function requestInfoFor(pubKey) {
            if (!root.contactInfoRequester || pubKey in requested)
                return

            requested[pubKey] = true
            // resolveFor() runs inside a QML binding, which must not call into the backend
            Qt.callLater(() => {
                if (root.contactInfoRequester)
                    root.contactInfoRequester(pubKey)
            })
        }

        function parseKnownNames(knownNames) {
            if (!knownNames)
                return {}
            if (typeof knownNames !== "string")
                return knownNames
            try {
                return JSON.parse(knownNames)
            } catch (e) {
                return {}
            }
        }

        // Not cached, so an empty answer - a provider that cannot reach its store yet,
        // whose function-literal binding never re-evaluates to say when it can - is
        // simply asked again on the next pass.
        function aliasOf(pubKey) {
            return root.aliasProvider ? (root.aliasProvider(pubKey) || null) : null
        }
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

import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import SortFilterProxyModel

import utils

/**
  * Non-visual worker behind the Android direct-share shortcuts: watches the
  * top of the recent postable destinations model (see
  * RecentPostableDestinationsAdaptor — single recency source, no duplicated
  * logic), renders each destination's avatar the same way the destination
  * picker does, and emits publishRequested with the shortcut payload whenever
  * the published set would actually change. Event-driven only: a successful
  * send updates the source model's recency, which reorders the top rows and
  * triggers a republish — no polling.
  *
  * Emits an intent signal out; the high-level consumer (AppMain) forwards the
  * payload to the platform (SystemUtils.publishShareShortcuts).
  */
Item {
    id: root

    /* Recency-sorted model of postable destinations; expected roles: chatId,
       name, color, colorId, icon, emoji (as rendered by the destination
       picker delegate) */
    required property var model

    /* The Android share sheet surfaces at most 4 direct-share targets */
    property int maxShortcuts: 4

    /* Directory the rendered avatars are written to; when empty, shortcuts
       are published without icons */
    property string iconDirectory

    /* Model churn coalescing window — a send updates several roles at once */
    property int debounceIntervalMs: 250

    /* shortcutsJson: JSON array of {id, name, iconPath?} in rank order (most
       recent first). An empty array means "clear the published set". */
    signal publishRequested(string shortcutsJson)

    // The avatar strip is render-only input for grabToImage: clipped away
    // visually (grabbing renders the delegates themselves, so the clip does
    // not affect the result), but it must stay visible — invisible items have
    // no scene-graph content to grab.
    width: 0
    height: 0
    clip: true

    QtObject {
        id: d

        readonly property int iconSize: 128

        // Visual identity of what was last published; republishing is skipped
        // when it would not change (e.g. the most recent chat got even more
        // recent, keeping the same order).
        property string lastPublishedSignature
        property int publishSeq: 0

        function schedulePublish() {
            debounceTimer.restart()
        }

        function collectEntries() {
            const entries = []
            const count = topDestinations.rowCount()
            for (let i = 0; i < count; i++) {
                const row = SQUtils.ModelUtils.get(topDestinations, i)
                entries.push({
                    id: row.chatId,
                    name: row.name,
                    color: String(row.color ?? ""),
                    colorId: String(row.colorId ?? ""),
                    icon: String(row.icon ?? ""),
                    emoji: String(row.emoji ?? "")
                })
            }
            return entries
        }

        function publish() {
            const entries = collectEntries()
            const signature = JSON.stringify(entries)
            if (signature === lastPublishedSignature)
                return

            publishSeq++
            const seq = publishSeq

            if (entries.length === 0 || root.iconDirectory === "") {
                emitPublish(signature, entries.map(e => ({ id: e.id, name: e.name })))
                return
            }

            // Icons are best effort: a shortcut without an avatar still works,
            // so a failed grab never holds the publication back.
            const iconPaths = new Array(entries.length).fill("")
            let remaining = entries.length
            const finishOne = function() {
                remaining--
                if (remaining > 0 || seq !== d.publishSeq)
                    return
                emitPublish(signature, entries.map((e, i) => {
                    const entry = { id: e.id, name: e.name }
                    if (iconPaths[i] !== "")
                        entry.iconPath = iconPaths[i]
                    return entry
                }))
            }

            for (let i = 0; i < entries.length; i++) {
                const item = avatarRepeater.itemAt(i)
                const path = "%1/shortcut-%2.png".arg(root.iconDirectory).arg(i)
                const index = i
                const grabbing = !!item && item.grabToImage(result => {
                    if (result.saveToFile(path))
                        iconPaths[index] = path
                    finishOne()
                })
                if (!grabbing)
                    finishOne()
            }
        }

        function emitPublish(signature, entries) {
            lastPublishedSignature = signature
            root.publishRequested(JSON.stringify(entries))
        }
    }

    // The source model is already postable-only and recency-sorted; the index
    // filter keeps the head of it.
    SortFilterProxyModel {
        id: topDestinations

        sourceModel: root.model

        filters: IndexFilter {
            maximumIndex: root.maxShortcuts - 1
        }
    }

    Connections {
        target: topDestinations

        function onDataChanged() { d.schedulePublish() }
        function onLayoutChanged() { d.schedulePublish() }
        function onModelReset() { d.schedulePublish() }
        function onRowsInserted() { d.schedulePublish() }
        function onRowsMoved() { d.schedulePublish() }
        function onRowsRemoved() { d.schedulePublish() }
    }

    Timer {
        id: debounceTimer

        interval: root.debounceIntervalMs
        onTriggered: d.publish()
    }

    Repeater {
        id: avatarRepeater

        model: topDestinations

        // Mirrors the destination picker delegate's avatar (StatusListItem
        // asset), so the share sheet shows the destinations exactly as the
        // picker does.
        delegate: StatusSmartIdenticon {
            width: d.iconSize
            height: d.iconSize
            name: model.name
            asset.width: d.iconSize
            asset.height: d.iconSize
            asset.color: model.color ? model.color
                                     : Utils.colorForColorId(Theme.palette, model.colorId)
            asset.name: model.icon ?? ""
            asset.emoji: model.emoji ?? ""
            asset.charactersLen: 2
        }
    }

    Component.onCompleted: d.schedulePublish()
}

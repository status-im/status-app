import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import AppLayouts.Browser.controls

/**
 * Download Pill strip (session-only — never fed from Download History).
 * Mobile: under the address bar. Desktop: window footer.
 * Newest pills insert at the left; existing pills animate right. Fixed width;
 * overflow scrolls horizontally.
 */
Rectangle {
    id: root

    property var downloadsModel: []

    readonly property int pillWidth: 227

    /// Both signals carry the Download Record — the one identity vocabulary
    /// for a download; no strip-index space to translate.
    signal openDownloadClicked(var record)
    /// anchor is the pill's ⋮ button — the menu right-aligns under (or over) it.
    signal optionsClicked(var record, Item anchor)
    signal close()

    // Figma File download: pills sit flush on a tinted strip, no card gaps, no border.
    color: Theme.palette.baseColor2
    implicitHeight: 44

    onDownloadsModelChanged: d.syncFromDownloadsModel()
    Component.onCompleted: d.syncFromDownloadsModel()

    QtObject {
        id: d

        readonly property int shiftDurationMs: 220

        /// Mirrors DownloadPill.highlighted for a neighbour the delegate can't reach.
        /// Index-based and bounds-checked — delegates outlive removals from the model.
        function isHighlightedAt(index) {
            if (index < 0 || index >= stripListModel.count)
                return false
            const record = stripListModel.get(index).record
            return !!record && !record.isTerminal
        }

        /// Mirror the JS-array store model into a ListModel so insert(0) emits
        /// rowsInserted + layout change — ListView can then run displaced animation.
        /// Full array reassignment alone would reset the view with no shift.
        function syncFromDownloadsModel() {
            const next = root.downloadsModel || []
            const nextLen = next.length

            if (nextLen === 0) {
                stripListModel.clear()
                return
            }

            // Prepend of one Record: new item at [0], previous strip is the tail.
            if (stripListModel.count > 0 && nextLen === stripListModel.count + 1) {
                let matches = true
                for (let i = 0; i < stripListModel.count; ++i) {
                    if (stripListModel.get(i).record !== next[i + 1]) {
                        matches = false
                        break
                    }
                }
                if (matches) {
                    stripListModel.insert(0, { record: next[0] })
                    listView.positionViewAtBeginning()
                    return
                }
            }

            // Single removal (dismiss / clear one pill).
            if (nextLen === stripListModel.count - 1 && stripListModel.count > 0) {
                for (let i = 0; i < stripListModel.count; ++i) {
                    const rec = stripListModel.get(i).record
                    let found = false
                    for (let j = 0; j < nextLen; ++j) {
                        if (next[j] === rec) {
                            found = true
                            break
                        }
                    }
                    if (!found) {
                        stripListModel.remove(i)
                        return
                    }
                }
            }

            // Fallback: rebuild without animation (initial bind / unexpected reorder).
            stripListModel.clear()
            for (let i = 0; i < nextLen; ++i)
                stripListModel.append({ record: next[i] })
            listView.positionViewAtBeginning()
        }
    }

    ListModel {
        id: stripListModel
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: listView
            objectName: "downloadPillListView"

            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: stripListModel

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: d.shiftDurationMs
                    easing.type: Easing.OutCubic
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "x"
                    duration: d.shiftDurationMs
                    easing.type: Easing.OutCubic
                }
            }

            removeDisplaced: Transition {
                NumberAnimation {
                    property: "x"
                    duration: d.shiftDurationMs
                    easing.type: Easing.OutCubic
                }
            }

            delegate: DownloadPill {
                id: pill

                required property var record
                required property int index

                download: record
                width: root.pillWidth
                height: ListView.view.height

                onItemClicked: root.openDownloadClicked(pill.record)
                onOptionsButtonClicked: function (anchor) {
                    root.optionsClicked(pill.record, anchor)
                }

                // Figma divider: only between two blended (terminal) pills — a
                // highlighted neighbour already separates them with its own card.
                Rectangle {
                    width: 1
                    height: 16
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.palette.baseColor1
                    visible: pill.index > 0 && !pill.highlighted
                             && !d.isHighlightedAt(pill.index - 1)
                }
            }
        }

        StatusFlatRoundButton {
            id: closeBtn
            objectName: "downloadPillStripClose"
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            icon.name: "close"
            type: StatusFlatRoundButton.Type.Quaternary
            onClicked: root.close()
        }
    }
}

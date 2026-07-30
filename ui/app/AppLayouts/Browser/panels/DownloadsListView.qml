import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls

/**
 * Downloads List for the tabs/bookmarks overview (issue 05 / UX 01–03).
 * Newest Records first; Missing File struck through; actions via menu / tap.
 * Active transfers mirror Download Pill: Pause|Resume left, Cancel right.
 */
Item {
    id: root

    property var downloadsModel: []
    property var statusTextFn: null
    property var elideFileNameFn: null

    signal openDownloadClicked(int index)
    /// anchor is the row's ⋮ button — the menu right-aligns under it.
    signal optionsClicked(int index, Item anchor)

    // Length, not Array.isArray: createObject converts JS arrays so isArray fails
    // while .length still reports Records (browser-downloads-polish 01).
    readonly property int _count: downloadsModel && downloadsModel.length !== undefined
                                  ? downloadsModel.length : 0

    StatusListView {
        id: listView
        objectName: "downloadsListView"
        anchors.fill: parent
        model: root.downloadsModel
        spacing: Theme.halfPadding
        clip: true

        delegate: ItemDelegate {
            id: row
            required property var modelData
            required property int index

            readonly property var record: modelData
            readonly property int listIndex: index

            // Same control matrix as DownloadPill for active / terminal Records.
            readonly property int primaryAction: {
                if (!record)
                    return DownloadPill.PrimaryAction.None
                const state = record.state
                if (state === AbstractWebView.DownloadState.DownloadCompleted)
                    return DownloadPill.PrimaryAction.File
                if (state === AbstractWebView.DownloadState.DownloadCancelled)
                    return DownloadPill.PrimaryAction.Cancelled
                if (state === AbstractWebView.DownloadState.DownloadPaused || record.isPaused)
                    return DownloadPill.PrimaryAction.Resume
                if (state === AbstractWebView.DownloadState.DownloadInProgress
                        || state === AbstractWebView.DownloadState.DownloadRequested)
                    return DownloadPill.PrimaryAction.Pause
                return DownloadPill.PrimaryAction.None
            }
            readonly property bool pauseButtonVisible:
                primaryAction === DownloadPill.PrimaryAction.Pause
            readonly property bool resumeButtonVisible:
                primaryAction === DownloadPill.PrimaryAction.Resume
            readonly property bool cancelButtonVisible:
                primaryAction === DownloadPill.PrimaryAction.Pause
                || primaryAction === DownloadPill.PrimaryAction.Resume
            readonly property bool optionsButtonVisible:
                primaryAction === DownloadPill.PrimaryAction.File
                || primaryAction === DownloadPill.PrimaryAction.None
                || primaryAction === DownloadPill.PrimaryAction.Cancelled

            readonly property string fileNameText: {
                const name = record?.fileName ?? ""
                if (!name)
                    return ""
                if (!root.elideFileNameFn || nameLabel.width <= 0)
                    return name
                if (nameMetrics.advanceWidth(name) <= nameLabel.width)
                    return name
                let lo = 4
                let hi = name.length
                let best = root.elideFileNameFn(name, lo)
                while (lo <= hi) {
                    const mid = Math.floor((lo + hi) / 2)
                    const candidate = root.elideFileNameFn(name, mid)
                    if (nameMetrics.advanceWidth(candidate) <= nameLabel.width) {
                        best = candidate
                        lo = mid + 1
                    } else {
                        hi = mid - 1
                    }
                }
                return best
            }

            width: ListView.view.width
            height: 56
            padding: Theme.halfPadding

            background: Rectangle {
                radius: Theme.radius
                color: row.hovered ? Theme.palette.primaryColor3 : StatusColors.transparent
            }

            // FontMetrics.advanceWidth(text) is a method; TextMetrics.advanceWidth is a property.
            FontMetrics {
                id: nameMetrics
                font: nameLabel.font
            }

            function triggerPrimaryAction() {
                if (!record)
                    return
                if (primaryAction === DownloadPill.PrimaryAction.Pause && record.pause)
                    record.pause()
                else if (primaryAction === DownloadPill.PrimaryAction.Resume && record.resume)
                    record.resume()
            }

            function triggerCancel() {
                if (!record || !cancelButtonVisible)
                    return
                if (record.cancel)
                    record.cancel()
            }

            contentItem: RowLayout {
                // Fill the content area so leading/trailing controls VCenter against
                // the full row (not a shrink-wrapped RowLayout top-aligned by Control).
                width: row.availableWidth
                height: row.availableHeight
                spacing: Theme.padding

                // Fixed leading slot — Pause/Resume is 32px, status icons are 24px;
                // without a shared width, filenames jog left/right by state.
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter

                    StatusFlatRoundButton {
                        id: primaryBtn
                        objectName: "downloadsListPrimaryButton"
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: row.pauseButtonVisible || row.resumeButtonVisible
                        icon.name: row.pauseButtonVisible ? "pause" : "play"
                        type: StatusFlatRoundButton.Type.Tertiary
                        onClicked: row.triggerPrimaryAction()
                    }

                    StatusIcon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        visible: !primaryBtn.visible
                        icon: record && record.state === AbstractWebView.DownloadState.DownloadCancelled
                              ? "downloads" : "file"
                        color: record && record.missingFile
                               ? Theme.palette.baseColor1
                               : (record && record.state === AbstractWebView.DownloadState.DownloadCancelled
                                  ? Theme.palette.baseColor1
                                  : Theme.palette.directColor1)
                        opacity: row.primaryAction === DownloadPill.PrimaryAction.None ? 0.5 : 1
                    }
                }

                ColumnLayout {
                    id: textColumn
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    StatusBaseText {
                        id: nameLabel
                        Layout.fillWidth: true
                        text: row.fileNameText
                        elide: Text.ElideNone
                        font.pixelSize: Theme.fontSize(14)
                        font.strikeout: !!(record && record.missingFile)
                        color: record && record.missingFile
                               ? Theme.palette.baseColor1
                               : Theme.palette.directColor1
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        readonly property string statusText: root.statusTextFn ? root.statusTextFn(record) : ""
                        visible: statusText.length > 0
                        text: statusText
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSize(12)
                        color: record && record.state === AbstractWebView.DownloadState.DownloadCancelled
                               ? Theme.palette.dangerColor1
                               : Theme.palette.baseColor1
                    }
                }

                // Fixed trailing slot so Cancel vs ⋮ does not shift the text column.
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter

                    StatusFlatRoundButton {
                        id: cancelBtn
                        objectName: "downloadsListCancelButton"
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: row.cancelButtonVisible
                        icon.name: "downloads-cancel"
                        type: StatusFlatRoundButton.Type.Tertiary
                        onClicked: row.triggerCancel()
                    }

                    StatusFlatRoundButton {
                        id: optionsBtn
                        objectName: "downloadsListOptionsButton"
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: row.optionsButtonVisible
                        icon.name: "more-v"
                        type: StatusFlatRoundButton.Type.Tertiary
                        onClicked: root.optionsClicked(row.listIndex, optionsBtn)
                    }
                }
            }

            onClicked: root.openDownloadClicked(row.listIndex)

            HoverHandler {
                cursorShape: hovered ? Qt.PointingHandCursor : undefined
            }
        }
    }

    StatusBaseText {
        objectName: "downloadsListEmptyLabel"
        visible: root._count === 0
        anchors.centerIn: parent
        text: qsTr("Downloaded files will appear here.")
        color: Theme.palette.secondaryText
    }
}

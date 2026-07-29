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
 */
Item {
    id: root

    property var downloadsModel: []
    property var statusTextFn: null
    property var elideFileNameFn: null

    signal openDownloadClicked(int index)
    signal optionsClicked(int index, Item anchor, real xVal)

    readonly property int _count: Array.isArray(downloadsModel) ? downloadsModel.length : 0

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
            readonly property string fileNameText: {
                const name = record?.fileName ?? ""
                if (!name || !root.elideFileNameFn || !nameLabel.width)
                    return name
                const avg = Math.max(1, nameMetrics.advanceWidth("x"))
                const maxChars = Math.max(4, Math.floor(nameLabel.width / avg))
                return root.elideFileNameFn(name, maxChars)
            }

            width: ListView.view.width
            height: 56
            padding: Theme.halfPadding

            background: Rectangle {
                radius: Theme.radius
                color: row.hovered ? Theme.palette.primaryColor3 : StatusColors.transparent
            }

            TextMetrics {
                id: nameMetrics
                font: nameLabel.font
            }

            contentItem: RowLayout {
                spacing: Theme.padding

                StatusIcon {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    icon: record && record.state === AbstractWebView.DownloadState.DownloadCancelled
                          ? "block-icon" : "file"
                    color: record && record.missingFile
                           ? Theme.palette.baseColor1
                           : (record && record.state === AbstractWebView.DownloadState.DownloadCancelled
                              ? Theme.palette.dangerColor1
                              : Theme.palette.directColor1)
                }

                ColumnLayout {
                    Layout.fillWidth: true
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
                        text: root.statusTextFn ? root.statusTextFn(record) : ""
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.palette.baseColor1
                    }
                }

                StatusFlatButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon.name: "more"
                    type: StatusBaseButton.Type.Tertiary
                    onClicked: root.optionsClicked(row.listIndex, row, x)
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

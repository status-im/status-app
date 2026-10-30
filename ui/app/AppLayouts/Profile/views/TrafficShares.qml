import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

//! A bar of shares and a legend row for each. A row with a kind is clickable.
ColumnLayout {
    id: root

    //! [{label, color, share, kind, key}], shares adding up to 1.
    property var shares: []
    //! Each row is named this plus its label.
    property string rowObjectNamePrefix

    signal shareClicked(string kind, string key)

    spacing: 10

    Row {
        id: bar

        Layout.fillWidth: true
        Layout.preferredHeight: 12

        Repeater {
            model: root.shares
            delegate: Rectangle {
                required property var modelData
                width: bar.width * modelData.share
                height: bar.height
                color: modelData.color
            }
        }
    }

    Repeater {
        model: root.shares

        delegate: AbstractButton {
            id: shareRow

            required property var modelData

            objectName: root.rowObjectNamePrefix + modelData.label
            Layout.fillWidth: true
            padding: 2
            enabled: !!modelData.kind
            Accessible.name: modelData.label

            HoverHandler {
                cursorShape: shareRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            onClicked: root.shareClicked(modelData.kind, modelData.key)

            contentItem: RowLayout {
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 3
                    color: shareRow.modelData.color
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    text: shareRow.modelData.label
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideMiddle
                }
                StatusBaseText {
                    text: qsTr("%1%").arg((100 * shareRow.modelData.share).toFixed(shareRow.modelData.share < 0.1 ? 1 : 0))
                    font.pixelSize: Theme.additionalTextSize
                    font.bold: true
                }
            }
        }
    }
}

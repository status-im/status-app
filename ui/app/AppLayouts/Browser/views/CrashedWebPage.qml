import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/// Shown in place of a Web View whose render process died.
Rectangle {
    id: root

    signal reloadRequested()

    color: Theme.palette.background

    // Centred block, left-aligned content. Sizes come straight from the design.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 2 * Theme.bigPadding, 420)
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            StatusIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: "exclamation_outline"
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                font.pixelSize: 19
                lineHeight: 26
                lineHeightMode: Text.FixedHeight
                color: Theme.palette.directColor1
                wrapMode: Text.WordWrap
                text: qsTr("Something went wrong")
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            font.pixelSize: 15
            lineHeight: 22
            lineHeightMode: Text.FixedHeight
            color: Theme.palette.directColor1
            wrapMode: Text.WordWrap
            text: qsTr("This page crashed and needs to be reloaded.")
        }

        StatusButton {
            Layout.alignment: Qt.AlignRight
            size: StatusBaseButton.Size.Small
            type: StatusBaseButton.Type.Primary
            text: qsTr("Reload")
            onClicked: root.reloadRequested()
        }
    }
}

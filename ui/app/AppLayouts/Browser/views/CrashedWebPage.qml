import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/// Shown in place of a Web View whose render process died.
/// Reloading is the user's call - see LazyWebViewAdapter.crashed.
Rectangle {
    id: root

    signal reloadRequested()

    color: Theme.palette.background

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.bigPadding, 420)
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.primaryTextFontSize
            font.weight: Font.Medium
            color: Theme.palette.directColor1
            text: qsTr("This page stopped working")
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.palette.baseColor1
            text: qsTr("Something went wrong while it was being displayed. Reloading usually brings it back.")
        }

        StatusButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.halfPadding
            text: qsTr("Reload")
            onClicked: root.reloadRequested()
        }
    }
}

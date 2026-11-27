import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/// Asks whether files of a type should open in Status (see DefaultViewerOffer).
Rectangle {
    id: root

    /// The type, as DefaultViewerTypes names it.
    property string typeName: ""
    /// Status opens the type now: the banner says so instead of asking.
    property bool confirmed: false

    signal acceptRequested()
    signal dismissRequested()
    signal acknowledged()

    implicitHeight: layout.implicitHeight + 2 * Theme.halfPadding
    color: Theme.palette.primaryColor3

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Theme.halfPadding
        anchors.leftMargin: Theme.padding
        spacing: Theme.halfPadding

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Theme.additionalTextSize
            text: root.confirmed
                  ? qsTr("Status opens your %1 now.").arg(root.typeName)
                  : qsTr("Open %1 in Status? Choose Status, then Always.").arg(root.typeName)
        }

        StatusFlatButton {
            objectName: "defaultViewerNotNowButton"
            visible: !root.confirmed
            size: StatusBaseButton.Size.Small
            text: qsTr("Not now")
            onClicked: root.dismissRequested()
        }

        StatusButton {
            objectName: "defaultViewerAcceptButton"
            size: StatusBaseButton.Size.Small
            text: root.confirmed ? qsTr("Got it") : qsTr("Choose")
            onClicked: root.confirmed ? root.acknowledged() : root.acceptRequested()
        }
    }
}

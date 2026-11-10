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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Theme.additionalTextSize
                text: root.confirmed
                      ? qsTr("Status opens your %1 now.").arg(root.typeName)
                      : qsTr("Open %1 in Status? Choose Status, then Always.").arg(root.typeName)
            }

            // Android offers Always only to the app on top when the user picked
            // another app for the type before, and Status cannot tell.
            StatusBaseText {
                objectName: "defaultViewerHint"
                Layout.fillWidth: true
                visible: !root.confirmed
                wrapMode: Text.Wrap
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
                text: qsTr("If Android suggests another app on top, clear that app's defaults in its settings first.")
            }
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

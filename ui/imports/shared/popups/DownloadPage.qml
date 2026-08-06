import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import "../panels"
import "."

Rectangle {
    id: root

    property string currentVersion: "0.0.0"
    property string newVersion: "0.0.0"
    property bool newVersionAvailable: true
    property string downloadURL: "https://github.com/status-im/status-app/releases/latest"
    signal closed()

    anchors.fill: parent
    color: Theme.palette.background

    StatusFlatRoundButton {
        type: StatusFlatRoundButton.Type.Quaternary
        icon.name: "close"
        anchors.top: parent.top
        anchors.topMargin: Theme.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        onClicked: root.closed()
    }

    SVGImage {
        id: logoImage
        source: Assets.svg(Theme.palette.name == "light" ? "status-logo-light" : "status-logo-dark")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 108
    }

    StatusBaseText {
        id: title
        text: qsTr("Thanks for using Status")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logoImage.bottom
        anchors.topMargin: 75
        font.pixelSize: Theme.fontSize(38)
        font.weight: Font.Medium
        color: Theme.palette.directColor1
    }

    StatusBaseText {
        id: currentVersionText
        text: qsTr("You're currently using version %1 of Status.").arg(root.currentVersion)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.topMargin: 32
        font.pixelSize: Theme.fontSize(28)
        color: Theme.palette.directColor1
    }

    StatusBaseText {
        id: newVersionAvailableText
        text: qsTr("There's new version available to download.")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: currentVersionText.bottom
        font.pixelSize: Theme.fontSize(28)
        color: Theme.palette.directColor1
    }

    StatusPickerButton {
        width: 175
        bgColor: Theme.palette.primaryColor1
        contentColor: StatusColors.white
        text: qsTr("Get Status %1").arg(root.newVersion)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: newVersionAvailableText.bottom
        anchors.topMargin: 32
        onClicked: {
            Global.requestOpenLink(root.downloadURL)
            root.closed()
        }
    }
}

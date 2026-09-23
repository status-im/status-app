import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.panels

ColumnLayout {
    id: root

    signal enableGifsRequested

    spacing: Theme.xlPadding

    SVGImage {
        Layout.alignment: Qt.AlignHCenter
        width: 132
        height: 94
        source: Assets.svg(`gifs-${Theme.palette.name}`)
    }

    StatusBaseText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: qsTr("Enable KLIPY GIFs?")
        font.weight: Font.Medium
    }

    StatusBaseText {
        Layout.fillWidth: true
        text: qsTr("Once enabled, GIFs posted in the chat may share your metadata with KLIPY.")
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.additionalTextSize
        color: Theme.palette.secondaryText
    }

    StatusButton {
        Layout.alignment: Qt.AlignRight
        objectName: "enableGifsButton"
        text: qsTr("Enable")

        onClicked: root.enableGifsRequested()
    }
}

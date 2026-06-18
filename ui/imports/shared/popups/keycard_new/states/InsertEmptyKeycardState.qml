import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import utils

Control {
    id: root

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            fillMode: Image.PreserveAspectFit
            mipmap: true
            source: Assets.png("keycard/card_insert/insert")
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
            color: Theme.palette.directColor1
            text: qsTr("Insert an empty Keycard")
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.palette.directColor1
            text: qsTr("Insert an empty Keycard you want to migrate your key pair to.")
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}

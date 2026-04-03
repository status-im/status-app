import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

Control {
    id: root

    signal confirmationUpdated(bool value)

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
            source: Assets.png("keycard/factory_reset/keycard-factory-reset")
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.palette.dangerColor1
            text: qsTr("A factory reset will delete the key on this Keycard.\nAre you sure you want to do this?")
        }

        StatusCheckBox {
            id: confirmation
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            spacing: Theme.smallPadding
            text: qsTr("I understand the key pair on this Keycard will be deleted")

            onCheckedChanged: {
                root.confirmationUpdated(checked)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}

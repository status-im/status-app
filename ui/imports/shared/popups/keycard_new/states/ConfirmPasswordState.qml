import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

Control {
    id: root

    required property string expectedPassword

    readonly property string password: input.text
    readonly property bool passwordMatches: input.text.length > 0 && input.text === root.expectedPassword

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {

        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Have you written down your password?")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            StatusBaseText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("You will never be able to recover your password if you loose it.")
                wrapMode: Text.WordWrap
                color: Theme.palette.dangerColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("If you need to, write it using pen and paper and keep in a safe place.")
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("If you loose your password you will loose access to your Status profile.")
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.padding
        }

        StatusPasswordInput {
            id: input

            property bool showPassword

            Layout.fillWidth: true
            Layout.leftMargin: 2*Theme.xlPadding
            Layout.rightMargin: 2*Theme.xlPadding
            placeholderText: qsTr("Confirm your password (again)")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideIcon.width + showHideIcon.anchors.rightMargin + Theme.padding / 2
            hasError: input.text.length > 0 && input.text !== root.expectedPassword
                      && input.text.length >= root.expectedPassword.length

            StatusFlatRoundButton {
                id: showHideIcon
                visible: input.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 24
                height: 24
                icon.name: input.showPassword ? "hide" : "show"
                icon.color: Theme.palette.baseColor1

                onClicked: input.showPassword = !input.showPassword
            }

            Component.onCompleted: {
                forceActiveFocus()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import utils

Control {
    id: root

    property bool wrongPassword: false

    property alias password: passwordInput.text
    readonly property bool passwordValid: passwordInput.text !== "" && !root.wrongPassword

    signal accepted()

    topPadding: Theme.halfPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            source: Assets.png("keycard/authenticate")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            text: qsTr("Enter your password")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusPasswordInput {
            id: passwordInput
            objectName: "authenticationPasswordInput"
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            placeholderText: qsTr("Password")
            selectByMouse: true
            focus: !SQUtils.Utils.isMobile

            onTextChanged: root.wrongPassword = false

            onAccepted: {
                if (root.passwordValid)
                    root.accepted()
            }
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            wrapMode: Text.WordWrap
            text: root.wrongPassword ? qsTr("Password incorrect") : ""
            color: Theme.palette.dangerColor1
            visible: root.wrongPassword
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus(Qt.MouseFocusReason)
    }
}

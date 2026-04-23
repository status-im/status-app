import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

Control {
    id: root

    property string keyPairName: ""
    property string initialKeyPairName: ""
    property string title: qsTr("Name your key pair")
    readonly property bool nameValid: nameInput.valid

    signal done()

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
            visible: !!root.title
            text: root.title
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusInput {
            id: nameInput
            Layout.preferredWidth: Constants.keycard.general.keycardNameInputWidth
            Layout.alignment: Qt.AlignHCenter
            charLimit: Constants.keypair.nameLengthMax
            validators: Constants.validators.keypairName
            placeholderText: qsTr("What would you like this key pair to be called?")
            input.acceptReturn: true

            onTextChanged: {
                root.keyPairName = text
            }

            onKeyPressed: {
                if (root.nameValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.done()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {
        if (root.initialKeyPairName.length > 0) {
            nameInput.text = root.initialKeyPairName
        }
        nameInput.input.edit.forceActiveFocus()
    }
}

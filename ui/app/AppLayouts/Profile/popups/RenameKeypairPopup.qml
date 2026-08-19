import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import shared.controls

import "../stores"

StatusModal {
    id: root

    required property var accountsModule
    required property string keyUid
    required property string name
    required property var accounts

    headerSettings.title: qsTr("Rename key pair")
    focus: visible
    padding: Theme.padding

    QtObject {
        id: d

        property bool entryValid: false

        function updateValidity() {
            d.entryValid = nameInput.valid
            if (!d.entryValid) {
                return
            }
            d.entryValid = d.entryValid && nameInput.text !== root.name
            if (!d.entryValid) {
                nameInput.errorMessageCmp.text = qsTr("Same name")
                nameInput.valid = false
                return
            }
            d.entryValid = d.entryValid && !root.accountsModule.keypairNameExists(nameInput.text)
            if (!d.entryValid) {
                nameInput.errorMessageCmp.text = qsTr("Key pair name already in use")
                nameInput.valid = false
            }
        }

        function confirm() {
            if (d.entryValid) {
                root.accountsModule.renameKeypair(root.keyUid, nameInput.text)
                root.close()
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        StatusInput {
            id: nameInput
            objectName: "renameKeypairNameInput"
            Layout.preferredWidth: parent.width
            topPadding: 8
            bottomPadding: 8
            label: qsTr("Key pair name")
            charLimit: Constants.keypair.nameLengthMax
            validators: Constants.validators.keypairName
            input.clearable: true
            input.rightPadding: 16
            text: root.name

            onTextChanged: {
                d.updateValidity()
            }
        }

        StatusBaseText {
            Layout.preferredWidth: parent.width
            Layout.topMargin: Theme.padding
            text: qsTr("Accounts derived from this key pair")
            font.pixelSize: Theme.primaryTextFontSize
        }

        Rectangle {
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 60
            color: "transparent"
            radius: 8
            border.width: 1
            border.color: Theme.palette.baseColor2

            StatusScrollView {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: contentHeight
                padding: 0
                leftPadding: 16
                rightPadding: 16

                Row {
                    spacing: 10
                    Repeater {
                        model: root.accounts
                        delegate: StatusListItemTag {
                            bgColor: Utils.getColorForId(Theme.palette, model.account.colorId)
                            height: Theme.bigPadding
                            bgRadius: 6
                            tagClickable: false
                            closeButtonVisible: false
                            asset {
                                emoji: model.account.emoji
                                emojiSize: Emoji.size.verySmall
                                isLetterIdenticon: !!model.account.emoji
                                name: model.account.icon
                                color: Theme.palette.indirectColor1
                                width: 16
                                height: 16
                            }
                            title: model.account.name
                            titleText.font.pixelSize: Theme.tertiaryTextFontSize
                            titleText.color: Theme.palette.indirectColor1
                        }
                    }
                }
            }
        }
    }

    rightButtons: [
        StatusFlatButton {
            text: qsTr("Cancel")
            type: StatusBaseButton.Type.Normal
            onClicked: {
                root.close()
            }
        },
        StatusButton {
            text: qsTr("Save changes")
            objectName: "saveRenameKeypairChangesButton"
            enabled: d.entryValid
            focus: true
            Keys.onReturnPressed: function(event) {
                d.confirm()
            }
            onClicked: {
                d.confirm()
            }
        }
    ]
}

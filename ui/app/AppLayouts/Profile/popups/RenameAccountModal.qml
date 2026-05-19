import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Controls.Validators

import utils

import shared.panels
import shared.controls

StatusModal {
    id: popup

    property var emojiPopup

    property string accountName
    property string accountEmoji
    property string accountColorId

    signal renameAccountRequested(string newName, string newColorId, string newEmoji)

    headerSettings.title: qsTr("Rename %1").arg(popup.accountName)
    padding: Theme.padding

    property int marginBetweenInputs: 30

    onOpened: {
        accountNameInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    Connections {
        enabled: popup.opened
        target: root.emojiPopup ?? null
        function onEmojiSelected(emojiText: string, atCursor: bool) {
            popup.contentItem.accountNameInput.input.asset.emoji = emojiText
        }
    }

    contentItem: Column {
        property alias accountNameInput: accountNameInput

        spacing: marginBetweenInputs

        StatusInput {
            id: accountNameInput

            width: parent.width
            input.edit.objectName: "renameAccountNameInput"
            input.isIconSelectable: true
            placeholderText: qsTr("Enter an account name...")
            input.text: popup.accountName
            input.asset.emoji: popup.accountEmoji
            input.asset.color: Utils.getColorForId(Theme.palette, popup.accountColorId)
            input.asset.name: popup.accountEmoji || "filled-account"

            validationMode: StatusInput.ValidationMode.Always

            onIconClicked: {
                popup.emojiPopup.open()
                popup.emojiPopup.directParent = accountNameInput
                popup.emojiPopup.relativeY = accountNameInput.height
            }
            validators: [
                StatusMinLengthValidator {
                    errorMessage: qsTr("Account name must be at least %n character(s)", "", Constants.addAccountPopup.keyPairAccountNameMinLength)
                    minLength: Constants.addAccountPopup.keyPairAccountNameMinLength
                },
                StatusRegularExpressionValidator {
                    regularExpression: /^[^<>]+$/
                    errorMessage: qsTr("This is not a valid account name")
                }
            ]
            charLimit: 20
        }

        StatusColorSelectorGrid {
            id: accountColorInput

            width: parent.width
            titleText: qsTr("COLOUR")
            selectedColor: Utils.getColorForId(Theme.palette, popup.accountColorId)
            selectedColorIndex: {
                for (let i = 0; i < model.length; i++) {
                    if(model[i].toString() === selectedColor)
                        return i
                }
                return -1
            }
            onColorSelected: color => {
                if(selectedColor !== popup.accountColorId) {
                    accountNameInput.input.asset.color = selectedColor
                }
            }
        }

        Item {
            width: parent.width
            height: 8
        }
    }

    rightButtons: [
        StatusButton {
            objectName: "renameAccountModalSaveBtn"
            text: qsTr("Change Name")

            enabled: accountNameInput.text !== "" &&
                     accountNameInput.valid &&
                     (accountNameInput.text !== popup.accountName ||
                      accountColorInput.selectedColorIndex >= 0 && accountColorInput.selectedColor !== popup.accountColorId ||
                      accountNameInput.input.asset.emoji !== popup.accountEmoji)

            StatusMessageDialog {
                id: changeError
                title: qsTr("Changing settings failed")
                icon: StatusMessageDialog.StandardIcon.Critical
            }

            onClicked : {
                if (!accountNameInput.valid) {
                    return
                }

                popup.renameAccountRequested(accountNameInput.text, Utils.getIdForColor(Theme.palette, accountColorInput.selectedColor), accountNameInput.input.asset.emoji)
                popup.close()
            }
        }
    ]
}

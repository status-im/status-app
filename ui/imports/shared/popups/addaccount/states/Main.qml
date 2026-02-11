import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils

import "../stores"
import "../panels"
import "../../common"

Item {
    id: root

    property AddAccountStore store

    signal watchOnlyAccountsLimitReached()
    signal keypairLimitReached()

    implicitHeight: layout.implicitHeight

    Component.onCompleted: {
        if (root.store.addAccountModule.selectedColorId === "") {
            colorSelection.selectedColorIndex = Math.floor(Math.random() * colorSelection.model.length)
        }
        else {
            let ind = Utils.getColorIndexForId(Theme.palette, root.store.addAccountModule.selectedColorId)
            colorSelection.selectedColorIndex = ind
        }

        if (root.store.addAccountModule.selectedEmoji === "") {
            // TODO: Reuse status-go RandomWalletEmoji
            root.store.addAccountModule.selectedEmoji = StatusQUtils.Emoji.getRandomEmoji(StatusQUtils.Emoji.size.verySmall)
        }

        accountName.text = root.store.addAccountModule.accountName
        if (root.store.addAccountModule.selectedEmoji !== "") {
            accountName.input.asset.emoji = root.store.addAccountModule.selectedEmoji;
        } else {
            accountName.input.asset.isLetterIdenticon = true;
        }

        if (!SQUtils.Utils.isMobile) {
            accountName.input.edit.forceActiveFocus()
        }
        accountName.validate(true)
    }

    QtObject {
        id: d
        readonly property bool isEdit: root.store.editMode

        function openEmojiPopup(showLeft) {
            if (!root.store.emojiPopup) {
                return
            }
            let inputCoords = accountName.mapToItem(appMain, 0, 0)
            root.store.emojiPopup.open()
            root.store.emojiPopup.emojiSize = StatusQUtils.Emoji.size.verySmall
            root.store.emojiPopup.directParent = accountName
            root.store.emojiPopup.relativeX = 0
            if (!showLeft) {
                root.store.emojiPopup.relativeX = accountName.width - root.store.emojiPopup.width
            }
            root.store.emojiPopup.relativeY = accountName.height + Theme.halfPadding
        }
    }

    Connections {
        target: root.store.emojiPopup

        function onEmojiSelected (emojiText, atCursor) {
            let emoji = StatusQUtils.Emoji.deparse(emojiText)
            root.store.addAccountModule.selectedEmoji = emoji
            accountName.input.asset.isLetterIdenticon = false
            accountName.input.asset.emoji = emojiText
        }
    }

    Component {
        id: spacer
        Rectangle {
            color: Theme.palette.baseColor4
        }
    }

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 0

        Loader {
            Layout.preferredHeight: root.Theme.defaultPadding
            Layout.fillWidth: true
            sourceComponent: spacer
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.padding

            Layout.margins: Theme.padding

            StatusInput {
                id: accountName
                objectName: "AddAccountPopup-AccountName"

                Layout.fillWidth: true

                placeholderText: qsTr("Account name")
                label: qsTr("Name")
                charLimit: 20
                text: root.store.addAccountModule.accountName
                input.isIconSelectable: true
                input.leftPadding: Theme.padding
                input.asset.color: Utils.getColorForId(Theme.palette, root.store.addAccountModule.selectedColorId)
                onIconClicked: {
                    d.openEmojiPopup(true)
                }
                input.rightComponent: StatusFlatRoundButton {
                    objectName: "AddAccountPopup-AccountEmoji"
                    width: 30
                    height: 30
                    radius: 30
                    icon.name: "emojis"
                    icon.width: 24
                    icon.height: 24
                    onClicked: {
                        d.openEmojiPopup(false)
                    }
                }
                validators: [
                    StatusMinLengthValidator {
                        errorMessage: qsTr("Account name must be at least %n character(s)", "", Constants.addAccountPopup.keyPairAccountNameMinLength)
                        minLength: Constants.addAccountPopup.keyPairAccountNameMinLength
                    },
                    StatusRegularExpressionValidator {
                        regularExpression: Constants.regularExpressions.alphanumericalWithSpace
                        errorMessage: Constants.errorMessages.alphanumericalWithSpaceRegExp
                    }
                ]

                onTextChanged: {
                    root.store.addAccountModule.accountName = text
                    if (input.asset.emoji === "") {
                        input.letterIconName = text;
                    }
                }

                onKeyPressed: event => {
                    root.store.submitPopup(event)
                }

                onValidChanged: {
                    root.store.accountNameIsValid = accountName.valid
                }
            }

            StatusColorSelectorGrid {
                id: colorSelection
                objectName: "AddAccountPopup-AccountColor"

                Layout.fillWidth: true
                model: Theme.palette.customisationColorsArray
                title.color: Theme.palette.directColor1
                title.text: qsTr("Colour")
                selectedColorIndex: -1

                onSelectedColorChanged: {
                    root.store.addAccountModule.selectedColorId = Utils.getIdForColor(Theme.palette, selectedColor)
                }
            }

            SelectOrigin {
                Layout.fillWidth: true

                userProfilePublicKey: root.store.userProfilePublicKey
                originModel: root.store.editMode? [] : root.store.originModel
                selectedOrigin: root.store.selectedOrigin
                caretVisible: !root.store.editMode
                enabled: !root.store.editMode

                onOriginSelected: {
                    if (keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc) {
                        if (root.store.remainingWatchOnlyAccountCapacity() === 0) {
                            root.watchOnlyAccountsLimitReached()
                            return
                        }
                    }
                    if (keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddNewMasterKey) {
                        if (root.store.remainingKeypairCapacity() === 0) {
                            root.keypairLimitReached()
                            return
                        }
                        root.store.currentState.doSecondaryAction()
                        return
                    }
                    root.store.changeSelectedOrigin(keyUid)
                }
            }

            WatchOnlyAddressSection {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin:  Theme.padding

                spacing: Theme.padding
                visible: !root.store.editMode &&
                         root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.unknown &&
                         root.store.selectedOrigin.keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc

                store: root.store

                onVisibleChanged: {
                    reset()
                }
            }
        }

        Loader {
            Layout.preferredHeight: Theme.padding
            Layout.fillWidth: true
            sourceComponent: spacer
        }

        DerivationPathSection {
            id: derivationPathSection
            Layout.fillWidth: true
            visible: root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.profile ||
                     root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.seedImport
            store: root.store
        }

        AddressWithAddressDetails {
            id: addressWithDetails
            Layout.fillWidth: true
            Layout.margins: Theme.padding
            spacing: Theme.halfPadding
            visible: root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.privateKeyImport ||
                     root.store.editMode &&
                     root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.unknown &&
                     root.store.selectedOrigin.keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc

            addressText: root.store.editMode? qsTr("Account") : qsTr("Public address of private key")
            addressDetailsItem: root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.privateKeyImport?
                                    root.store.privateKeyAccAddress
                                  : root.store.watchOnlyAccAddress
            displayDetails: !root.store.editMode
            displayCopyButton: root.store.editMode
            addressColor: root.store.editMode? Theme.palette.baseColor1 : Theme.palette.directColor1
        }

        Loader {
            Layout.preferredHeight: Theme.padding
            Layout.fillWidth: true
            visible: derivationPathSection.visible || addressWithDetails.visible
            sourceComponent: spacer
        }
    }
}

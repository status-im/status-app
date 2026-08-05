import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups

import utils

Item {
    id: root

    property BasePopupStore store

    QtObject {
        id: d

        property bool showPassword: false
        property bool addressResolved: root.store.privateKeyAccAddress.address !== ""
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.padding
        spacing: Theme.padding

        Column {
            width: parent.width
            spacing: Theme.halfPadding

            StatusBaseText {
                width: parent.width
                text: root.store.isAddAccountPopup? qsTr("Private key") : qsTr("Enter recovery phrase for %1 key pair").arg(root.store.selectedKeypair.name)
                elide: Text.ElideRight
            }

            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: Theme.padding
                rowSpacing: Theme.halfPadding

                StatusPasswordInput {
                    id: privKeyInput
                    objectName: "AddAccountPopup-PrivateKeyInput"
                    Layout.preferredHeight: Constants.addAccountPopup.itemHeight
                    Layout.preferredWidth: parent.width - parent.columnSpacing - showHideButton.width
                    rightPadding: pasteButton.width + pasteButton.anchors.rightMargin + Theme.halfPadding
                    wrapMode: TextEdit.Wrap
                    placeholderText: qsTr("Type or paste your private key")
                    echoMode: d.showPassword ? TextInput.Normal : TextInput.Password

                    onTextChanged: {
                        root.store.enteredPrivateKeyIsValid = Utils.isPrivateKey(text)
                        if (root.store.enteredPrivateKeyIsValid) {
                            root.store.changePrivateKeyPostponed(text)
                            return
                        }
                        root.store.cleanPrivateKey()
                    }

                    onPressed: {
                        root.store.submitPopup(event)
                    }

                    StatusPasteButton {
                        id: pasteButton
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.padding
                        onPasted: (text) => privKeyInput.text = text
                    }
                }

                StatusFlatRoundButton {
                    id: showHideButton
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    icon.name: d.showPassword ? "hide" : "show"
                    icon.color: Theme.palette.baseColor1
                    onClicked: d.showPassword = !d.showPassword
                }

                StatusBaseText {
                    Layout.alignment: Qt.AlignRight
                    visible: privKeyInput.text !== "" && !(root.store.enteredPrivateKeyIsValid && root.store.enteredPrivateKeyMatchTheKeypair)
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.dangerColor1
                    text: {
                        if (!root.store.enteredPrivateKeyIsValid)
                            return qsTr("Private key invalid")
                        if (!root.store.enteredPrivateKeyMatchTheKeypair)
                            return qsTr("This is not the correct private key")
                        return ""
                    }
                }
            }
        }

        StatusInput {
            width: privKeyInput.width
            maximumHeight: Constants.addAccountPopup.importPrivateKeyWarningHeight
            minimumHeight: Constants.addAccountPopup.importPrivateKeyWarningHeight
            visible: !d.addressResolved
            multiline: true
            leftPadding: Theme.padding
            font.pixelSize: Theme.additionalTextSize
            text: qsTr("New addresses cannot be derived from an account imported from a private key. Import using a recovery phrase if you wish to derive addresses.")
            input.edit.enabled: false
            input.enabled: false
            input.background.color: "transparent"
            input.background.border.color: Theme.palette.baseColor2
            input.leftComponent: StatusIcon {
                icon: "info"
                height: 20
                width: 20
                color: Theme.palette.baseColor1
            }
        }

        AddressWithAddressDetails {
            width: parent.width
            spacing: Theme.halfPadding
            visible: d.addressResolved

            addressText: qsTr("Public address of private key")
            addressDetailsItem: root.store.privateKeyAccAddress
            addressResolved: d.addressResolved
            displayCopyButton: false
            alreadyCreatedAccountIsAnError: root.store.isAddAccountPopup
        }

        StatusModalDivider {
            width: parent.width
            visible: root.store.isAddAccountPopup && d.addressResolved
        }

        Column {
            width: parent.width
            spacing: Theme.halfPadding
            visible: root.store.isAddAccountPopup && d.addressResolved

            StatusInput {
                objectName: "AddAccountPopup-PrivateKeyName"
                width: parent.width
                label: qsTr("Key name")
                charLimit: Constants.addAccountPopup.keyPairNameMaxLength
                placeholderText: qsTr("Enter a name")
                text: root.store.isAddAccountPopup? root.store.addAccountModule.newKeyPairName : ""

                onTextChanged: {
                    if (!root.store.isAddAccountPopup) {
                        return
                    }
                    if (text.trim() == "") {
                        root.store.addAccountModule.newKeyPairName = ""
                        return
                    }
                    root.store.addAccountModule.newKeyPairName = text
                }

                onKeyPressed: {
                    root.store.submitPopup(event)
                }

                validators: [
                    StatusMinLengthValidator {
                        errorMessage: qsTr("Key pair name must be at least %n character(s)", "", Constants.addAccountPopup.keyPairAccountNameMinLength)
                        minLength: Constants.addAccountPopup.keyPairAccountNameMinLength
                    }
                ]
            }

            StatusBaseText {
                text: qsTr("For your future reference. This is only visible to you.")
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
            }
        }
    }
}

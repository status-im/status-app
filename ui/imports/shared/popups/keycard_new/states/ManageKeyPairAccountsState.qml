import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls

import utils
import shared.popups

import "../helpers"

Control {
    id: root

    property var emojiPopup: null
    property string keyPairName: ""
    property string userProfilePublicKey: ""

    readonly property bool allAccountsValid: d.allAccountsValid
    readonly property int numberOfAddedAccounts: accountsList.count

    signal done()

    function addAccount() {
        const color = Theme.palette.customisationColorsArray[Math.floor(Math.random() * Theme.palette.customisationColorsArray.length)]
        const emoji = StatusQUtils.Emoji.getRandomEmoji(StatusQUtils.Emoji.size.verySmall)
        const colorId = Utils.getIdForColor(Theme.palette, color)
        accountsList.append({
                                name: "",
                                colorId: colorId,
                                emoji: emoji
                            })
        d.setObservedAccount(accountsList.count - 1)
        accountNameInput.input.edit.forceActiveFocus()
    }

    function getAccountsJson() {
        let accounts = []
        for (let i = 0; i < accountsList.count; i++) {
            const acc = accountsList.get(i)
            accounts.push({
                              name: acc.name.trim(),
                              colorId: acc.colorId,
                              emoji: acc.emoji,
                              path: Constants.walletRootPath + "/" + i
                          })
        }
        return JSON.stringify(accounts)
    }

    ListModel {
        id: accountsList
    }

    Component.onCompleted: {
        root.addAccount()
        if (!StatusQUtils.Utils.isMobile) {
            accountNameInput.input.edit.forceActiveFocus()
        }
    }

    QtObject {
        id: d

        property bool allAccountsValid: false

        property int observedAccountIndex: -1
        property string observedAccountName: ""
        property string observedAccountColorId: ""
        property string observedAccountEmoji: ""

        property string accountNameToBeRemoved: ""
        property int accountIndexToBeRemoved: -1

        function setObservedAccount(idx) {
            if (idx < 0 || idx >= accountsList.count)
                return
            d.observedAccountIndex = idx
            const acc = accountsList.get(idx)

            accountNameInput.text = acc.name
            d.observedAccountColorId = acc.colorId
            d.observedAccountEmoji = acc.emoji

            for (let i = 0; i < Theme.palette.customisationColorsArray.length; i++) {
                if (Utils.getIdForColor(Theme.palette, Theme.palette.customisationColorsArray[i]) === acc.colorId) {
                    colorSelection.selectedColorIndex = i
                    break
                }
            }
        }

        function updateObservedName() {
            if (d.observedAccountIndex < 0)
                return
            accountsList.setProperty(d.observedAccountIndex, "name", d.observedAccountName)
            d.updateValidity()
        }

        function updateObservedColorId() {
            if (d.observedAccountIndex < 0)
                return
            accountsList.setProperty(d.observedAccountIndex, "colorId", d.observedAccountColorId)
        }

        function updateObservedEmoji() {
            if (d.observedAccountIndex < 0)
                return
            accountsList.setProperty(d.observedAccountIndex, "emoji", d.observedAccountEmoji)
        }

        function updateValidity() {
            let valid = accountsList.count > 0
            for (let i = 0; i < accountsList.count; i++) {
                if (accountsList.get(i).name.trim().length === 0) {
                    valid = false
                    break
                }
            }
            d.allAccountsValid = valid
        }

        function removeAccount(idx) {
            accountsList.remove(idx)
            if (accountsList.count === 0) {
                d.observedAccountIndex = -1
            } else if (d.observedAccountIndex >= accountsList.count) {
                d.setObservedAccount(accountsList.count - 1)
            } else if (d.observedAccountIndex === idx) {
                d.setObservedAccount(Math.min(idx, accountsList.count - 1))
            }
            d.updateValidity()
        }

        onObservedAccountNameChanged: d.updateObservedName()
        onObservedAccountColorIdChanged: d.updateObservedColorId()
        onObservedAccountEmojiChanged: d.updateObservedEmoji()
    }

    Connections {
        target: root.emojiPopup
        enabled: root.emojiPopup !== null

        function onEmojiSelected(emojiText, atCursor) {
            d.observedAccountEmoji = StatusQUtils.Emoji.deparse(emojiText)
        }
    }

    ConfirmationDialog {
        id: confirmationPopup
        headerSettings.title: qsTr("Remove account")
        confirmationText: d.accountNameToBeRemoved.length > 0
            ? qsTr("Do you want to delete the \"%1\" account?").arg(d.accountNameToBeRemoved)
            : qsTr("Do you want to delete this account?")
        confirmButtonLabel: qsTr("Yes, delete this account")
        onConfirmButtonClicked: {
            confirmationPopup.close()
            d.removeAccount(d.accountIndexToBeRemoved)
        }
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Name your accounts")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusInput {
            id: accountNameInput
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            charLimit: Constants.keycard.general.keycardNameLength
            placeholderText: qsTr("What would you like this account to be called?")
            input.acceptReturn: true
            input.isIconSelectable: root.emojiPopup !== null
            input.leftPadding: Theme.padding
            input.asset.color: Utils.getColorForId(Theme.palette, d.observedAccountColorId)
            input.asset.emoji: d.observedAccountEmoji

            onTextChanged: {
                d.observedAccountName = text
            }

            onKeyPressed: {
                if (root.allAccountsValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.done()
                }
            }

            onIconClicked: {
                if (!root.emojiPopup)
                    return
                root.emojiPopup.open()
                root.emojiPopup.emojiSize = StatusQUtils.Emoji.size.verySmall
                root.emojiPopup.directParent = accountNameInput
                root.emojiPopup.relativeY = accountNameInput.height + Theme.halfPadding
            }
        }

        StatusColorSelectorGrid {
            id: colorSelection
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            title.text: qsTr("Colour")
            model: Theme.palette.customisationColorsArray

            onSelectedColorChanged: {
                d.observedAccountColorId = Utils.getIdForColor(Theme.palette, selectedColor)
            }
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignLeft
            text: qsTr("Preview")
            color: Theme.palette.baseColor1
        }

        KeyPairCompactItem {
            Layout.fillWidth: true
            tagClickable: true
            tagDisplayRemoveAccountButton: accountsList.count > 1

            userProfilePublicKey: root.userProfilePublicKey

            keyPairType: Constants.keycard.keyPairType.seedImport
            keyPairName: root.keyPairName
            keyPairIcon: "key_pair_seed_phrase"
            keyPairAccounts: accountsList

            onRemoveAccount: function(idx, accName) {
                if (accName.trim().length > 0) {
                    d.accountIndexToBeRemoved = idx
                    d.accountNameToBeRemoved = accName
                    confirmationPopup.open()
                } else {
                    d.removeAccount(idx)
                }
            }

            onAccountClicked: function(idx) {
                d.setObservedAccount(idx)
                accountNameInput.input.edit.forceActiveFocus()
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Wallet.stores as WalletStore

import utils
import shared.popups

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule
    property var emojiPopup

    signal validation(bool result)

    QtObject {
        id: d
        property var observedAccount: root.sharedKeycardModule.keyPairForProcessing.observedAccount
        property bool entryValid: false
        property string emptyName: "      "
        property string accountNameToBeRemoved: ""
        property int accountIndexToBeRemoved: -1
        property string observedImportingAccountShortAddress: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                                                  StatusQUtils.Utils.elideText(root.sharedKeycardModule.keyPairHelper.observedAccount.address, 6, 4)
                                                                : ""

        onObservedAccountChanged: {
            if (d.observedAccount.name.trim().length > 0) {
                accountName.text = d.observedAccount.name
            }
            else {
                accountName.text = ""
                d.observedAccount.name = d.emptyName
            }

            if (d.observedAccount.colorId.length === 0) {
                let color = Theme.palette.customisationColorsArray[Math.floor(Math.random() * Theme.palette.customisationColorsArray.length)]
                let emoji = StatusQUtils.Emoji.getRandomEmoji(StatusQUtils.Emoji.size.verySmall) // TODO: Reuse status-go RandomWalletEmoji
                d.observedAccount.colorId = Utils.getIdForColor(root.Theme.palette, color)
                d.observedAccount.emoji = emoji
            }

            let ind = d.evaluateColorIndex(d.observedAccount.colorId)
            colorSelection.selectedColorIndex = ind
            d.updateValidity()
            accountName.input.edit.forceActiveFocus()
        }

        function updateValidity() {
            d.entryValid = d.observedAccount.name.trim().length > 0
            root.validation(d.entryValid)
        }

        function evaluateColorIndex(color) {
            for (let i = 0; i < Theme.palette.customisationColorsArray.length; i++) {
                if(Theme.palette.customisationColorsArray[i] === color) {
                    return i
                }
            }
            return 0
        }
    }

    Component.onCompleted: {
        d.updateValidity()
        if (!SQUtils.Utils.isMobile) {
            accountName.input.edit.forceActiveFocus()
        }
    }

    Connections {
        target: root.emojiPopup
        enabled: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                 root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                 root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard

        function onEmojiSelected (emojiText, atCursor) {
            let emoji = StatusQUtils.Emoji.deparse(emojiText)
            d.observedAccount.emoji = emoji
        }
    }

    ConfirmationDialog {
        id: confirmationPopup
        headerSettings.title: qsTr("Remove account")
        confirmationText: d.accountNameToBeRemoved.length > 0?
                              qsTr("Do you want to delete the %1 account?").arg(d.accountNameToBeRemoved)
                            : qsTr("Do you want to delete the last account?")
        confirmButtonLabel: qsTr("Yes, delete this account")
        onConfirmButtonClicked: {
            confirmationPopup.close();
            root.sharedKeycardModule.keyPairForProcessing.removeAccountAtIndex(d.accountIndexToBeRemoved)
        }
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusStepper {
            id: stepper
            Layout.fillWidth: true
        }

        TitleText {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: accountDetails
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            visible: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard
            implicitHeight: accountDetailsLayout.implicitHeight + Theme.padding * 2
            color: "transparent"
            border.color: Theme.palette.baseColor2
            border.width: 1
            radius: Theme.halfPadding

            RowLayout {
                id: accountDetailsLayout
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding

                ColumnLayout {
                    StatusBaseText {
                        text: d.observedImportingAccountShortAddress
                        wrapMode: Text.WordWrap
                        color: Theme.palette.baseColor1
                    }

                    StatusBaseText {
                        text: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                  root.sharedKeycardModule.keyPairHelper.observedAccount.path : ""
                        wrapMode: Text.WordWrap
                        color: Theme.palette.baseColor1
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.height
                }

                ColumnLayout {
                    StatusBaseText {
                        text: qsTr("Balance: %1").arg(LocaleUtils.currencyAmountToLocaleString(root.sharedKeycardModule.keyPairHelper.observedAccount.balance))
                        wrapMode: Text.WordWrap
                        color: Theme.palette.baseColor1
                    }

                    Row {
                        padding: 0

                        StatusBaseText {
                            text: qsTr("View on Etherscan")
                            wrapMode: Text.WordWrap
                            color: Theme.palette.baseColor1
                        }

                        StatusFlatRoundButton {
                            height: 20
                            width: 20
                            icon.name: "external"
                            icon.width: 16
                            icon.height: 16
                            onClicked: {
                                let link = Utils.getUrlForAddressOnNetwork(Constants.networkShortChainNames.mainnet,
                                                                           WalletStore.RootStore.areTestNetworksEnabled,
                                                                           root.sharedKeycardModule.keyPairHelper.observedAccount.address)
                                Global.requestOpenLink(link)
                            }
                        }
                    }
                }
            }
        }

        StatusInput {
            id: accountName
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            charLimit: Constants.keycard.general.keycardNameLength
            placeholderText: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                    return qsTr("What name should account %1 have?").arg(d.observedImportingAccountShortAddress)
                }

                return qsTr("What would you like this account to be called?")
            }
            input.acceptReturn: true
            input.isIconSelectable: true
            input.leftPadding: Theme.padding
            input.asset.color: Utils.getColorForId(Theme.palette, d.observedAccount.colorId)
            input.asset.emoji: d.observedAccount.emoji

            onTextChanged: {
                d.observedAccount.name = text.trim().length > 0? text : d.emptyName
                d.updateValidity()
            }

            onKeyPressed: {
                if (d.entryValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }

            onIconClicked: {
                let inputCoords = accountName.mapToItem(appMain, 0, 0)
                root.emojiPopup.open()
                root.emojiPopup.emojiSize = StatusQUtils.Emoji.size.verySmall
                root.emojiPopup.directParent = accountName
                root.emojiPopup.relativeY = accountName.height + Theme.halfPadding
            }
        }

        StatusColorSelectorGrid {
            id: colorSelection
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            title.text: qsTr("Colour")
            model: Theme.palette.customisationColorsArray

            onSelectedColorChanged: {
                d.observedAccount.colorId = Utils.getIdForColor(Theme.palette, selectedColor)
            }
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignLeft
            text: qsTr("Preview")
            color: Theme.palette.baseColor1
        }

        KeyPairItem {
            Layout.fillWidth: true
            tagClickable: true
            tagDisplayRemoveAccountButton: root.sharedKeycardModule.currentState.flowType !== Constants.keycardSharedFlow.importFromKeycard
            keyPairType: root.sharedKeycardModule.keyPairForProcessing.pairType
            keyPairKeyUid: root.sharedKeycardModule.keyPairForProcessing.keyUid
            keyPairName: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                             root.sharedKeycardModule.keyPairHelper.name
                           : root.sharedKeycardModule.keyPairForProcessing.name
            keyPairIcon: root.sharedKeycardModule.keyPairForProcessing.icon
            keyPairImage: root.sharedKeycardModule.keyPairForProcessing.image
            keyPairDerivedFrom: root.sharedKeycardModule.keyPairForProcessing.derivedFrom
            keyPairAccounts: root.sharedKeycardModule.keyPairForProcessing.accounts
            keyPairCardLocked: root.sharedKeycardModule.keyPairForProcessing.locked

            onRemoveAccount: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard)
                    return
                if (name.trim().length == 0) {
                    root.sharedKeycardModule.keyPairForProcessing.removeAccountAtIndex(index)
                    return
                }
                d.accountIndexToBeRemoved = index
                d.accountNameToBeRemoved = name
                confirmationPopup.open()
            }

            onAccountClicked: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                    root.sharedKeycardModule.keyPairHelper.setAccountAtIndexAsObservedAccount(index)
                }
                root.sharedKeycardModule.keyPairForProcessing.setAccountAtIndexAsObservedAccount(index)
            }
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.manageKeycardAccounts
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.manageKeycardAccounts
            PropertyChanges {
                target: stepper
                visible: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard &&
                         root.sharedKeycardModule.keyPairHelper.accounts.count > 1
                totalSteps: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                root.sharedKeycardModule.keyPairHelper.accounts.count : 0
                completedSteps: root.sharedKeycardModule.keyPairForProcessing.accounts.count
                title: qsTr("Account %1 of %2").arg(completedSteps).arg(totalSteps)
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                        return qsTr("Name account %1").arg(d.observedImportingAccountShortAddress)
                    }

                    return qsTr("Name accounts")
                }
            }
            PropertyChanges {
                target: accountDetails
                visible: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard &&
                         root.sharedKeycardModule.keyPairHelper.accounts.count > 1
            }
        }
    ]
}

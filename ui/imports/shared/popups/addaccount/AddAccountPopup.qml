import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils
import shared.popups

import "./stores"
import "./states"
import "../common"

StatusModal {
    id: root

    property AddAccountStore store: AddAccountStore { }

    property bool isKeycardEnabled: true

    fullScreenSheet: true
    width: Constants.addAccountPopup.popupWidth

    closePolicy: root.store.disablePopup? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
    hasCloseButton: !root.store.disablePopup

    headerSettings.title: root.store.editMode? qsTr("Edit account") : qsTr("Add a new account")

    onOpened: {
        root.store.resetStoreValues()

        root.store.showLimitPopup.connect(limitPopup.showPopup)
    }

    onClosed: {
        root.store.currentState.doCancelAction()
    }

    Connections {
        target: root.store.addAccountModule
        function onConfirmSavedAddressRemoval(name, address) {
            Global.openPopup(confirmSavedAddressRemoval, {address: address, name: name})
        }
    }

    StatusScrollView {
        id: scrollView

        anchors.fill: parent
        contentWidth: availableWidth

        Item {
            id: content
            objectName: "AddAccountPopup-Content"

            implicitWidth: loader.implicitWidth
            implicitHeight: loader.implicitHeight
            width: scrollView.availableWidth

            Loader {
                id: limitPopup
                active: false

                property string title
                property string content

                function showPopup(warningType) {
                    if (warningType === Constants.LimitWarning.Accounts) {
                        limitPopup.title = Constants.walletConstants.maxNumberOfAccountsTitle
                        limitPopup.content = Constants.walletConstants.maxNumberOfAccountsContent
                    } else if (warningType === Constants.LimitWarning.Keypairs) {
                        limitPopup.title = Constants.walletConstants.maxNumberOfKeypairsTitle
                        limitPopup.content = Constants.walletConstants.maxNumberOfKeypairsContent
                    } else if (warningType === Constants.LimitWarning.WatchOnlyAccounts) {
                        limitPopup.title = Constants.walletConstants.maxNumberOfWatchOnlyAccountsTitle
                        limitPopup.content = Constants.walletConstants.maxNumberOfSavedAddressesContent
                    } else {
                        console.error("unsupported warning type")
                        return
                    }

                    limitPopup.active = true
                }

                sourceComponent: StatusDialog {
                    width: root.width - 2*Theme.padding

                    property string contentText

                    title: Constants.walletConstants.maxNumberOfAccountsTitle

                    StatusBaseText {
                        anchors.fill: parent
                        text: contentText
                        wrapMode: Text.WordWrap
                    }

                    standardButtons: Dialog.Ok

                    onClosed: {
                        limitPopup.active = false
                    }
                }

                onLoaded: {
                    limitPopup.item.title = limitPopup.title
                    limitPopup.item.contentText = limitPopup.content
                    limitPopup.item.open()
                }
            }

            Loader {
                id: loader
                width: parent.width
                sourceComponent: {
                    switch (root.store.currentState.stateType) {
                    case Constants.addAccountPopup.state.main:
                        return mainComponent
                    case Constants.addAccountPopup.state.confirmAddingNewMasterKey:
                        return confirmAddingNewMasterKeyComponent
                    case Constants.addAccountPopup.state.confirmSeedPhraseBackup:
                        return confirmSeedPhraseBackupComponent
                    case Constants.addAccountPopup.state.displaySeedPhrase:
                        return displaySeedPhraseComponent
                    case Constants.addAccountPopup.state.enterKeypairName:
                        return enterKeypairNameComponent
                    case Constants.addAccountPopup.state.enterPrivateKey:
                        return enterPrivateKeyComponent
                    case Constants.addAccountPopup.state.enterSeedPhraseWord1:
                    case Constants.addAccountPopup.state.enterSeedPhraseWord2:
                        return enterSeedPhraseWordComponent
                    case Constants.addAccountPopup.state.enterSeedPhrase:
                        return enterSeedPhraseComponent
                    case Constants.addAccountPopup.state.selectMasterKey:
                        return selectMasterKeyComponent
                    }

                    return undefined
                }

                onLoaded: {
                    content.height = Qt.binding(function(){return item.height})
                }
            }

            Component {
                id: mainComponent
                Main {
                    store: root.store

                    onWatchOnlyAccountsLimitReached: {
                        limitPopup.showPopup(Constants.LimitWarning.WatchOnlyAccounts)
                    }
                    onKeypairLimitReached: {
                        limitPopup.showPopup(Constants.LimitWarning.Keypairs)
                    }
                }
            }

            Component {
                id: confirmAddingNewMasterKeyComponent
                ConfirmAddingNewMasterKey {
                    onAllAcceptedChanged: {
                        root.store.addingNewMasterKeyConfirmed = allAccepted
                    }

                    Component.onCompleted: {
                        if (root.store.addingNewMasterKeyConfirmed)
                            setAllAccepted()
                    }
                }
            }

            Component {
                id: confirmSeedPhraseBackupComponent
                ConfirmSeedPhraseBackup {
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                }
            }

            Component {
                id: displaySeedPhraseComponent
                DisplaySeedPhrase {
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                }
            }

            Component {
                id: enterKeypairNameComponent
                EnterKeypairName {
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                }
            }

            Component {
                id: enterPrivateKeyComponent
                EnterPrivateKey {
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                }
            }

            Component {
                id: enterSeedPhraseComponent
                EnterSeedPhrase {
                    store: root.store
                }
            }

            Component {
                id: enterSeedPhraseWordComponent
                EnterSeedPhraseWord {
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                }
            }

            Component {
                id: selectMasterKeyComponent
                SelectMasterKey {
                    isKeycardEnabled: root.isKeycardEnabled
                    height: Constants.addAccountPopup.contentHeight1
                    store: root.store
                    onContinueOnKeycard: {
                        root.close()
                    }
                }
            }
        }

        Component {
            id: confirmSavedAddressRemoval

            ConfirmationDialog {

                property string name
                property string address

                closePolicy: Popup.NoAutoClose
                hasCloseButton: false
                headerSettings.title: qsTr("Removing saved address")
                confirmationText: qsTr("The account you're trying to add <b>%1</b> is already saved under the name <b>%2</b>.<br/><br/>Do you want to remove it from saved addresses in favour of adding it to the Wallet?")
                .arg(address)
                .arg(name)
                showCancelButton: true
                cancelBtnType: ""
                confirmButtonLabel: qsTr("Yes")
                cancelButtonLabel: qsTr("No")

                onConfirmButtonClicked: {
                    root.store.addAccountModule.removingSavedAddressConfirmed(address)
                    close()
                }

                onCancelButtonClicked: {
                    root.store.addAccountModule.removingSavedAddressRejected()
                    close()
                }
            }
        }
    }

    leftButtons: [
        StatusBackButton {
            id: backButton
            objectName: "AddAccountPopup-BackButton"
            visible: root.store.currentState.displayBackButton
            enabled: !root.store.disablePopup

            Layout.minimumWidth: implicitWidth

            onClicked: {
                if (root.store.currentState.stateType === Constants.addAccountPopup.state.confirmAddingNewMasterKey) {
                    root.store.addingNewMasterKeyConfirmed = false
                }
                else if (root.store.currentState.stateType === Constants.addAccountPopup.state.displaySeedPhrase) {
                    root.store.seedPhraseRevealed = false
                }
                else if (root.store.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhraseWord1) {
                    root.store.seedPhraseWord1Valid = false
                    root.store.seedPhraseWord1WordNumber = -1
                    root.store.seedPhraseWord2Valid = false
                    root.store.seedPhraseWord2WordNumber = -1
                }
                else if (root.store.currentState.stateType === Constants.addAccountPopup.state.confirmSeedPhraseBackup) {
                    root.store.seedPhraseBackupConfirmed = false
                }
                else if (root.store.currentState.stateType === Constants.addAccountPopup.state.enterKeypairName) {
                    root.store.addAccountModule.newKeyPairName = ""
                }

                root.store.currentState.doBackAction()
            }
        }
    ]

    rightButtons: [
        StatusButton {
            id: primaryButton
            objectName: "AddAccountPopup-PrimaryButton"
            type: root.store.currentState.stateType === Constants.addAccountPopup.state.main?
                      StatusBaseButton.Type.Primary :
                      StatusBaseButton.Type.Normal
            height: Constants.addAccountPopup.footerButtonsHeight
            text: {
                if (root.store.editMode) {
                    return qsTr("Save changes")
                }

                switch (root.store.currentState.stateType) {

                case Constants.addAccountPopup.state.main:
                    return qsTr("Add account")
                case Constants.addAccountPopup.state.enterPrivateKey:
                case Constants.addAccountPopup.state.enterSeedPhrase:
                case Constants.addAccountPopup.state.enterSeedPhraseWord1:
                case Constants.addAccountPopup.state.enterSeedPhraseWord2:
                case Constants.addAccountPopup.state.confirmSeedPhraseBackup:
                case Constants.addAccountPopup.state.enterKeypairName:
                    return qsTr("Continue")
                case Constants.addAccountPopup.state.confirmAddingNewMasterKey:
                    return qsTr("Reveal recovery phrase")
                case Constants.addAccountPopup.state.displaySeedPhrase:
                    return qsTr("Confirm recovery phrase")
                }

                return ""
            }
            visible: text !== ""
            enabled: root.store.primaryPopupButtonEnabled

            icon.name: {
                if (root.store.editMode) {
                    return ""
                }

                if (root.store.currentState.stateType === Constants.addAccountPopup.state.enterPrivateKey ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhrase ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.confirmAddingNewMasterKey ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.displaySeedPhrase ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhraseWord1 ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhraseWord2 ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.confirmSeedPhraseBackup ||
                        root.store.currentState.stateType === Constants.addAccountPopup.state.enterKeypairName ||
                        root.store.addAccountModule.actionAuthenticated ||
                        root.store.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.unknown &&
                        root.store.selectedOrigin.keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc) {
                    return ""
                }

                if (root.store.selectedOrigin.keyUid === root.store.userProfileKeyUid &&
                        root.store.userProfileUsingBiometricLogin) {
                    return "touch-id"
                }

                if (root.store.selectedOrigin.migratedToKeycard || root.store.userProfileIsKeycardUser) {
                    return "keycard"
                }

                return "password"
            }

            onClicked: {
                root.store.submitPopup(null)
            }
        }
    ]
}

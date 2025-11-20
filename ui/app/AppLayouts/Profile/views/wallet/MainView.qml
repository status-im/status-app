import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components

import utils
import shared.status
import shared.panels
import shared.popups
import shared.popups.addaccount

import "../../stores"
import "../../controls"
import "../../popups"

Column {
    id: root

    property WalletStore walletStore
    property var emojiPopup

    property bool isKeycardEnabled: true

    signal goToNetworksView()
    signal goToAccountOrderView()
    signal goToAccountView(var account)
    signal goToManageTokensView()
    signal goToSavedAddressesView()

    signal runRenameKeypairFlow(var model)
    signal runRemoveKeypairFlow(var model)
    signal runMoveKeypairToKeycardFlow(var model)
    signal runStopUsingKeycardFlow(var model)

    spacing: 8

    Connections {
        target: walletSection

        function onDisplayAddAccountPopup() {
            addAccount.active = true
        }
        function onDestroyAddAccountPopup() {
            addAccount.active = false
        }
    }

    QtObject {
        id: d

        property bool propertyReevaluation: false
        readonly property int unimportedNonProfileKeypairs: {
            d.propertyReevaluation
            let total = 0
            for (var i = 0; i < keypairsRepeater.count; i++) {
                let item = keypairsRepeater.itemAt(i)
                if (item == undefined || item == null) {
                    continue
                }
                let kp = item.keyPair
                if (kp.migratedToKeycard ||
                        kp.pairType === Constants.keypair.type.profile ||
                        kp.pairType === Constants.keypair.type.watchOnly ||
                        kp.operability === Constants.keypair.operability.fullyOperable ||
                        kp.operability === Constants.keypair.operability.partiallyOperable) {
                    continue
                }
                total++
            }
            return total
        }

        readonly property int allNonProfileKeypairsMigratedToAKeycard: {
            d.propertyReevaluation
            for (var i = 0; i < keypairsRepeater.count; i++) {
                let item = keypairsRepeater.itemAt(i)
                if (item == undefined || item == null) {
                    continue
                }
                let kp = item.keyPair
                if (!kp.migratedToKeycard &&
                        kp.pairType !== Constants.keypair.type.profile &&
                        kp.pairType !== Constants.keypair.type.watchOnly &&
                        kp.operability !== Constants.keypair.operability.nonOperable) {
                    return false
                }
            }
            return true
        }

    }

    component Spacer: Item {
        height: 8
    }


    Loader {
        id: addAccount
        active: false

        sourceComponent: AddAccountPopup {
            isKeycardEnabled: root.isKeycardEnabled
            store.emojiPopup: root.emojiPopup
            store.addAccountModule: walletSection.addAccountModule
        }

        onLoaded: {
            addAccount.item.open()
        }
    }

    Separator {}

    StatusListItem {
        objectName: "networksItem"
        title: qsTr("Networks")
        height: 64
        width: parent.width
        onClicked: goToNetworksView()
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
    }

    Separator {}

    StatusListItem {
        id: accountOrderItem
        objectName: "accountOrderItem"
        title: qsTr("Account order")
        height: 64
        width: parent.width
        onClicked: goToAccountOrderView()
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
    }

    Separator {}

    StatusListItem {
        id: manageTokensItem
        objectName: "manageTokensItem"
        title: qsTr("Manage Tokens")
        height: 64
        width: parent.width
        onClicked: goToManageTokensView()
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
    }

    Separator {}

    StatusListItem {
        objectName: "savedAddressesItem"
        title: qsTr("Saved Addresses")
        height: 64
        width: parent.width
        onClicked: goToSavedAddressesView()
        components: [
            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        ]
    }

    Separator {}

    Spacer {
        visible: root.walletStore.walletModule.hasPairedDevices
        width: parent.width
    }

    // TODO uncomment when mobile has implemented the QR code import
    // Rectangle {
    //     visible: root.walletStore.walletModule.hasPairedDevices &&
    //              !d.allNonProfileKeypairsMigratedToAKeycard
    //     height: 102
    //     width: parent.width
    //     color: StatusColors.transparent
    //     radius: 8
    //     border.width: 1
    //     border.color: Theme.palette.baseColor5

    //     Column {
    //         anchors.fill: parent
    //         padding: 16
    //         spacing: 8

    //         StatusBaseText {
    //             text: qsTr("Import key pairs from this device to your other synced devices")
    //             font.pixelSize: Theme.primaryTextFontSize
    //         }

    //         StatusButton {
    //             text: qsTr("Show encrypted QR of key pairs on device")
    //             icon.name: "qr"
    //             onClicked: {
    //                 root.walletStore.runKeypairImportPopup("", Constants.keypairImportPopup.mode.exportKeypairQr)
    //             }
    //         }
    //     }
    // }

    Rectangle {
        visible: root.walletStore.walletModule.hasPairedDevices &&
                 d.unimportedNonProfileKeypairs > 0
        height: 102
        width: parent.width
        color: StatusColors.transparent
        radius: 8
        border.width: 1
        border.color: Theme.palette.baseColor5

        Column {
            anchors.fill: parent
            padding: 16
            spacing: 8

            StatusBaseText {
                text: qsTr("%n key pair(s) require import to use on this device", "", d.unimportedNonProfileKeypairs)
                font.pixelSize: Theme.primaryTextFontSize
            }

            StatusButton {
                text: qsTr("Import missing key pairs")
                type: StatusBaseButton.Type.Warning
                icon.name: "download"
                onClicked: {
                    root.walletStore.runKeypairImportPopup("", Constants.keypairImportPopup.mode.selectKeypair)
                }
            }
        }
    }

    Spacer {
        width: parent.width
    }

    Column {
        width: parent.width
        spacing: 24
        Repeater {
            id: keypairsRepeater
            objectName: "generatedAccounts"
            model: walletStore.originModel
            onItemAdded: {
                d.propertyReevaluation = !d.propertyReevaluation
            }
            onItemRemoved: {
                d.propertyReevaluation = !d.propertyReevaluation
            }

            delegate: WalletKeyPairDelegate {
                width: parent.width
                keyPair: model.keyPair
                hasPairedDevices: root.walletStore.walletModule.hasPairedDevices
                userProfilePublicKey: walletStore.userProfilePublicKey
                onGoToAccountView: (account) => root.goToAccountView(account)
                onRunRenameKeypairFlow: root.runRenameKeypairFlow(model)
                onRunRemoveKeypairFlow: root.runRemoveKeypairFlow(model)
                onRunImportViaSeedPhraseFlow: {
                    root.walletStore.runKeypairImportPopup(model.keyPair.keyUid, Constants.keypairImportPopup.mode.importViaSeedPhrase)
                }
                onRunImportViaPrivateKeyFlow: {
                    root.walletStore.runKeypairImportPopup(model.keyPair.keyUid, Constants.keypairImportPopup.mode.importViaPrivateKey)
                }
                onRunExportQrFlow: {
                    root.walletStore.runKeypairImportPopup(model.keyPair.keyUid, Constants.keypairImportPopup.mode.exportKeypairQr)
                }
                onRunImportViaQrFlow: {
                    root.walletStore.runKeypairImportPopup(model.keyPair.keyUid, Constants.keypairImportPopup.mode.importViaQr)
                }
                onRunMoveKeypairToKeycardFlow: {
                    root.runMoveKeypairToKeycardFlow(model)
                }
                onRunStopUsingKeycardFlow: {
                    root.runStopUsingKeycardFlow(model)
                }
            }
        }
    }
}

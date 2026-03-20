import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.controls
import shared.views
import shared.stores as SharedStores
import utils

// TODO: replace with StatusMenu
Dialog {
    id: root

    required property bool incognitoMode
    // model of wallet accounts for the dropdown
    required property var accounts
    // currently selected wallet account
    required property var currentAccount
    required property var activityStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore

    signal sendTriggered(string address)
    signal reload()
    signal accountChanged(string newAddress)
    signal accountSwitchRequested(string address)
    signal filterAddressesChangeRequested(string addressesJson)

    modal: false

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Overlay.overlay
    implicitWidth: 720
    height: 480
    background: Rectangle {
        id: bgPopup
        color: root.incognitoMode ?
                   Theme.palette.privacyColors.primary:
                   Theme.palette.background
        radius: Theme.radius
        layer.enabled: true
        layer.effect: DropShadow {
            width: bgPopup.width
            height: bgPopup.height
            x: bgPopup.x
            y: bgPopup.y + 10
            visible: bgPopup.visible
            source: bgPopup
            horizontalOffset: 0
            verticalOffset: 5
            radius: 10
            samples: 15
            color: Theme.palette.dropShadow
        }
    }
    padding: Theme.padding

    Item {
        id: walletHeader
        width: parent.width
        height: childrenRect.height

        // TODO: Uncomment and connect to connector in next PR
        // Network indicator showing current chain
        /*
        Rectangle {
            id: networkColorCircle
            width: 8
            height: 8
            radius: width / 2
            color: {
                // TODO: Get chainId from connectorBridge instead of web3ProviderStore
                // Example: connectorBridge.chainId
                switch (root.web3ProviderStore.chainName) {
                    case Constants.networkMainnet: return Theme.palette.successColor1
                    case Constants.networkRopsten: return Theme.palette.mentionColor1
                    default: return Theme.palette.warningColor1
                }
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StatusBaseText {
            id: networkText
            text: {
                // TODO: Get chainId from connectorBridge and map to chainName
                // Example: getChainName(connectorBridge.chainId)
                switch (root.web3ProviderStore.chainName) {
                    case Constants.networkMainnet: return qsTr("Mainnet");
                    case Constants.networkRopsten: return qsTr("Ropsten");
                    default: return qsTr("Unknown")
                }
            }
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: networkColorCircle.right
            anchors.leftMargin: Theme.halfPadding
            color: Theme.palette.directColor1
            font.pixelSize: 13
        }
        */
    }


    Connections {
        target: root.currentAccount
        function onConnectedAccountDeleted() {
            root.reload()
            // This is done because when an account is deleted and the account is updated to default one,
            // only the properties are updated and we need to listen to those events and update the selected account
            accountSelectorRow.currentAddress = ""
            accountSelector.selectedAddress = Qt.binding(function () {return root.currentAccount.address})
        }
    }

    Item {
        property string currentAddress: ""
        id: accountSelectorRow
        width: parent.width
        height: accountSelector.height
        anchors.top: walletHeader.bottom
        anchors.topMargin: Theme.padding

        AccountSelector {
            id: accountSelector
            anchors.left: parent.left
            anchors.right: copyBtn.left
            anchors.rightMargin: Theme.padding

            control.popup.background: Rectangle {
                radius: Theme.radius
                color: root.incognitoMode ?
                           Theme.palette.privacyColors.primary:
                           Theme.palette.background
                border.color: root.incognitoMode ?
                                  Theme.palette.privacyColors.secondary:
                                  Theme.palette.border
            }

            model: root.accounts
            selectedAddress: root.currentAccount.address
            onCurrentAccountAddressChanged: {
                if (!accountSelectorRow.currentAddress) {
                    // We just set the account for the first time. Nothing to do here
                    accountSelectorRow.currentAddress = currentAccountAddress
                    return
                }
                if (accountSelectorRow.currentAddress === currentAccountAddress) {
                    return
                }

                accountSelectorRow.currentAddress = currentAccountAddress
                root.accountSwitchRequested(currentAccountAddress)
                root.accountChanged(currentAccountAddress)
                root.filterAddressesChangeRequested(JSON.stringify([currentAccountAddress]))

                reload()
            }
        }

        CopyToClipBoardButton {
            id: copyBtn
            width: 20
            height: 20
            anchors.right: sendBtn.left
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: accountSelector.verticalCenter
            color: StatusColors.transparent
            textToCopy: accountSelector.currentAccountAddress
            onCopyClicked: ClipboardUtils.setText(textToCopy)
        }

        StatusFlatRoundButton {
            id: sendBtn
            width: 40
            height: 40
            anchors.right: parent.right
            anchors.verticalCenter: accountSelector.verticalCenter
            icon.name: "send"
            onClicked: sendTriggered(accountSelector.currentAccountAddress)
        }
    }

    HistoryView {
        id: walletInfoContent
        width: parent.width
        anchors.top: accountSelectorRow.bottom
        anchors.topMargin: Theme.bigPadding
        anchors.bottom: parent.bottom

        activityStore: root.activityStore
        overview: root.currentAccount
        communitiesStore: null
        currencyStore: root.currencyStore
        networksStore: root.networksStore
        showAllAccounts: false
        displayValues: true
        filterVisible: false
        disableShadowOnScroll: true
        hideVerticalScrollbar: false
    }
    onClosed: {
        root.destroy();
    }
}

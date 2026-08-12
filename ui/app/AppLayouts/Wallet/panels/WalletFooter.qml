import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import QtModelsToolkit

import StatusQ
import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils
import shared.controls

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.Wallet.stores as WalletStores

import "../controls"
import "../popups"

Rectangle {
    id: root

    readonly property alias anyActionAvailable: d.anyActionAvailable

    property WalletStores.RootStore walletStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    required property TransactionStore transactionStore

    property bool swapEnabled
    property bool buyEnabled

    property real widthBreakpoint: 600 // Width at which the buttons will be displayed in a single row, with no text

    signal launchShareAddressModal()
    signal launchSendModal(string fromAddress)
    signal launchSwapModal()
    signal launchBuyCryptoModal()

    implicitHeight: 61
    color: Theme.palette.statusAppLayout.rightPanelBackgroundColor

    QtObject {
        id: d
        readonly property bool isCollectibleViewed: !!walletStore.currentViewedHoldingTokenGroupKey &&
                                                    (walletStore.currentViewedHoldingType === Constants.TokenType.ERC721 ||
                                                     walletStore.currentViewedHoldingType === Constants.TokenType.ERC1155)

        readonly property bool isCommunityAsset: !d.isCollectibleViewed && walletStore.currentViewedHoldingCommunityId !== ""

        readonly property bool isCollectibleSoulbound: isCollectibleViewed && !!walletStore.currentViewedCollectible && walletStore.currentViewedCollectible.soulbound

        readonly property bool isCollectibleOwnerToken: isCollectibleViewed && !!walletStore.currentViewedCollectible &&
                                                        walletStore.currentViewedCollectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner

        readonly property var viewedAssetGroupEntry: ModelEntry {
            sourceModel: walletStore.tokensStore.tokenGroupsModel ?? null
            key: "key"
            value: !d.isCollectibleViewed ? (walletStore.currentViewedHoldingTokenGroupKey ?? "") : ""
        }

        // Soulbound community tokens (e.g. TMaster) can never be sent
        readonly property bool isAssetSoulbound: viewedAssetGroupEntry.available &&
                                                 !!viewedAssetGroupEntry.item &&
                                                 !!viewedAssetGroupEntry.item.soulbound

        // The community owner token is sent only via "Manage community" -> "Tokens"
        readonly property bool isAssetOwnerToken: viewedAssetGroupEntry.available &&
                                                  !!viewedAssetGroupEntry.item &&
                                                  !!viewedAssetGroupEntry.item.ownerToken

        readonly property bool isSoulbound: isCollectibleSoulbound || isAssetSoulbound
        readonly property bool isOwnerToken: isCollectibleOwnerToken || isAssetOwnerToken

        readonly property var collectibleOwnership: isCollectibleViewed && walletStore.currentViewedCollectible ?
                                                        walletStore.currentViewedCollectible.ownership : null

        readonly property string userOwnedAddressForCollectible: !!walletStore.currentViewedHoldingTokenGroupKey ? getFirstUserOwnedAddress(collectibleOwnership, root.walletStore.nonWatchAccounts) : ""

        readonly property bool hideCollectibleTransferActions: isCollectibleViewed && !userOwnedAddressForCollectible

        /// Actions available
        readonly property bool anyActionAvailable: sendActionAvailable
                                                   || receiveActionAvailable
                                                   || buyActionAvailable
                                                   || swapActionAvailable

        readonly property bool sendActionAvailable: !walletStore.overview.isWatchOnlyAccount
                                                    && walletStore.overview.canSend
                                                    && !d.hideCollectibleTransferActions
        
        readonly property bool receiveActionAvailable: !walletStore.showAllAccounts

        readonly property bool buyActionAvailable: !isCollectibleViewed && root.buyEnabled

        readonly property bool swapActionAvailable: root.swapEnabled
                                                    && !walletStore.overview.isWatchOnlyAccount
                                                    && walletStore.overview.canSend
                                                    && !d.isCollectibleViewed
                                                    && !d.isCommunityAsset

        function getFirstUserOwnedAddress(ownershipModel, accountsModel) {
            if (!ownershipModel) return ""
            
            for (let i = 0; i < ownershipModel.rowCount(); i++) {
                const accountAddress = SQUtils.ModelUtils.get(ownershipModel, i, "accountAddress")
                if (SQUtils.ModelUtils.contains(accountsModel, "address", accountAddress, Qt.CaseInsensitive))
                    return accountAddress
            }
            return ""
        }
    }

    StatusModalDivider {
        anchors.top: parent.top
        width: parent.width
    }

    RowLayout {
        id: layout
        readonly property bool showText: root.width >= root.widthBreakpoint
        anchors.centerIn: parent
        height: parent.height
        width: Math.min(root.width, implicitWidth)
        spacing: Theme.padding

        StatusFlatButton {
            id: sendButton
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            objectName: "walletFooterSendButton"
            icon.name: "send"
            text: qsTr("Send")
            interactive: !d.isSoulbound && !d.isOwnerToken && networkConnectionStore.walletReadyForTransactionsEnabled
            onClicked: {
                root.transactionStore.setSenderAccount(root.walletStore.selectedAddress)
                root.launchSendModal(d.isCollectibleViewed ? d.userOwnedAddressForCollectible: root.walletStore.selectedAddress)
            }
            tooltip.text: d.isSoulbound ? qsTr("Soulbound tokens cannot be sent to another wallet")
                                        : d.isOwnerToken ? qsTr("Go to \"Manage community -> Tokens\" page to send it")
                                                         : networkConnectionStore.walletReadyForTransactionsToolTipText
            visible: d.sendActionAvailable
            display: layout.showText ? StatusFlatButton.TextBesideIcon : StatusFlatButton.IconOnly
        }

        StatusFlatButton {
            objectName: "walletFooterReceiveButton"
            icon.name: "receive"
            text: qsTr("Receive")
            visible: d.receiveActionAvailable
            onClicked: function () {
                root.transactionStore.setReceiverAccount(root.walletStore.selectedAddress)
                launchShareAddressModal()
            }
            display: layout.showText ? StatusFlatButton.TextBesideIcon : StatusFlatButton.IconOnly
        }

        StatusFlatButton {
            id: buySellBtn
            objectName: "walletFooterBuyButton"

            visible: d.buyActionAvailable
            icon.name: "token"
            text: qsTr("Buy")
            onClicked: root.launchBuyCryptoModal()
            display: layout.showText ? StatusFlatButton.TextBesideIcon : StatusFlatButton.IconOnly
        }

        StatusFlatButton {
            id: swap
            objectName: "walletFooterSwapButton"

            interactive: networkConnectionStore.walletReadyForTransactionsEnabled
            visible: d.swapActionAvailable
            tooltip.text: networkConnectionStore.walletReadyForTransactionsToolTipText
            icon.name: "swap"
            text: qsTr("Swap")
            onClicked: root.launchSwapModal()
            display: layout.showText ? StatusFlatButton.TextBesideIcon : StatusFlatButton.IconOnly
        }
    }
}



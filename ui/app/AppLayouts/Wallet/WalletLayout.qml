import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Layout
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Core.Theme

import utils
import shared.controls
import shared.popups.keypairimport

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.Communities.stores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppLayoutsStores

import QtModelsToolkit

import "popups"
import "panels"
import "views"
import "stores"
import "controls"
import "popups/swap"
import "popups/buy"

Item {
    id: root

    property Item navBar

    property WalletStores.RootStore walletRootStore
    property SharedStores.RootStore sharedRootStore
    property AppLayoutsStores.RootStore store
    property AppLayoutsStores.ContactsStore contactsStore
    property CommunitiesStore communitiesStore
    required property TransactionStore transactionStore
    required property SharedStores.NetworksStore networksStore

    property var emojiPopup: null
    property SharedStores.NetworkConnectionStore networkConnectionStore
    property bool appMainVisible

    property bool swapEnabled
    property bool dAppsEnabled
    property bool dAppsVisible

    property var dAppsModel

    property bool isKeycardEnabled: true

    signal dappListRequested()
    signal dappConnectRequested()
    signal dappDisconnectRequested(string dappUrl)

    signal manageNetworksRequested()

    // TODO: remove tokenType parameter from signals below
    signal sendTokenRequested(string senderAddress, string gorupKey, int tokenType)
    signal bridgeTokenRequested(string tokenId, int tokenType)

    signal openSwapModalRequested(var swapFormData)

    onAppMainVisibleChanged: {
        resetView()
    }

    onVisibleChanged: {
        resetView()
    }

    Connections {
        target: walletSection

        function onFilterChanged(address) {
            RootStore.selectedAddress = address === "" ? "" : address
        }

        function onDisplayKeypairImportPopup() {
            keypairImport.active = true
        }

        function onDestroyKeypairImportPopup() {
            keypairImport.active = false
        }
    }

    enum LeftPanelSelection {
        AllAddresses,
        Address,
        SavedAddresses,
        FollowingAddresses
    }

    enum RightPanelSelection {
        Assets,
        Collectibles,
        Activity
    }

    function resetView() {
        if (!visible || !appMainVisible) {
            return
        }

        d.displayAllAddresses()

        d.resetRightPanelStackView()
    }

    function openDesiredView(leftPanelSelection, rightPanelSelection, data) {
        if (leftPanelSelection !== WalletLayout.LeftPanelSelection.AllAddresses &&
                leftPanelSelection !== WalletLayout.LeftPanelSelection.SavedAddresses &&
                leftPanelSelection !== WalletLayout.LeftPanelSelection.FollowingAddresses &&
                leftPanelSelection !== WalletLayout.LeftPanelSelection.Address) {
            console.warn("not supported left selection", leftPanelSelection)
            return
        }

        if (leftPanelSelection === WalletLayout.LeftPanelSelection.SavedAddresses) {
            d.displaySavedAddresses()
        } else if (leftPanelSelection === WalletLayout.LeftPanelSelection.FollowingAddresses) {
            d.displayFollowingAddresses()
        } else {
            let address = data.address ?? ""
            if (leftPanelSelection === WalletLayout.LeftPanelSelection.AllAddresses) {
                d.displayAllAddresses()
            } else if (leftPanelSelection === WalletLayout.LeftPanelSelection.Address) {
                if (!!address) {
                    d.displayAddress(address)
                } else {
                    d.displayAllAddresses()
                }
            }

            if (rightPanelSelection !== WalletLayout.RightPanelSelection.Collectibles &&
                    rightPanelSelection !== WalletLayout.RightPanelSelection.Assets &&
                    rightPanelSelection !== WalletLayout.RightPanelSelection.Activity) {
                console.warn("not supported right selection", rightPanelSelection)
                return
            }

            d.resetRightPanelStackView()
            rightPanelStackView.currentItem.currentTabIndex = rightPanelSelection

            let savedAddress = data.savedAddress?? ""
            if (!!savedAddress) {
                RootStore.currentActivityFiltersStore.resetAllFilters()
                RootStore.currentActivityFiltersStore.toggleSavedAddress(savedAddress)
            }
        }

        // In portrait mode, it automatically swipes to the detailed content
        walletSectionLayout.goToNextPanel()
    }

    QtObject {
        id: d

        readonly property bool showSavedAddresses: RootStore.showSavedAddresses
        onShowSavedAddressesChanged: {
            if(showSavedAddresses) {
                rightPanelStackView.replace(cmpSavedAddresses)
                RootStore.backButtonName = ""
            } else if (!showFollowingAddresses) {
                // Only replace with walletContainer if we're not showing following addresses
                rightPanelStackView.replace(walletContainer)
                RootStore.backButtonName = ""
            }
        }

        readonly property bool showFollowingAddresses: RootStore.showFollowingAddresses
        onShowFollowingAddressesChanged: {
            if(showFollowingAddresses) {
                rightPanelStackView.replace(cmpFollowingAddresses)
                RootStore.backButtonName = ""
            } else if (!showSavedAddresses) {
                // Only replace with walletContainer if we're not showing saved addresses
                rightPanelStackView.replace(walletContainer)
                RootStore.backButtonName = ""
            }
        }

        property BuyCryptoParamsForm buyFormData: BuyCryptoParamsForm {
            selectedWalletAddress: RootStore.selectedAddress
        }

        function displayAllAddresses() {
            RootStore.showSavedAddresses = false
            RootStore.showFollowingAddresses = false
            RootStore.selectedAddress = ""
            RootStore.setFilterAllAddresses()
        }

        function displayAddress(address) {
            RootStore.showSavedAddresses = false
            RootStore.showFollowingAddresses = false
            RootStore.selectedAddress = address
            d.resetRightPanelStackView() // Avoids crashing on asset items being destroyed while in signal handler
            RootStore.setFilterAddress(address)
        }

        function displaySavedAddresses() {
            RootStore.showSavedAddresses = true
            RootStore.showFollowingAddresses = false
            RootStore.selectedAddress = ""
        }

        function displayFollowingAddresses() {
            RootStore.showSavedAddresses = false
            RootStore.showFollowingAddresses = true
            RootStore.selectedAddress = ""
        }

        function resetRightPanelStackView() {
            if (rightPanelStackView.currentItem && !!rightPanelStackView.currentItem.resetView) {
                rightPanelStackView.currentItem.resetView()
            }
        }

        function getSelectedOrFirstNonWatchedAddress() {
            return !!RootStore.selectedAddress ?
                    RootStore.selectedAddress :
                    StatusQUtils.ModelUtils.get(RootStore.nonWatchAccounts, 0, "address")
        }

        function launchBuyCryptoModal() {
            const walletStore = RootStore

            d.buyFormData.selectedWalletAddress = d.getSelectedOrFirstNonWatchedAddress()
            d.buyFormData.selectedNetworkChainId = StatusQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "layer", 1, "chainId")
            if(!!walletStore.currentViewedHoldingTokenGroupKey && walletStore.currentViewedHoldingType === Constants.TokenType.ERC20) {
                d.buyFormData.selectedTokenKey =  walletStore.currentViewedHoldingTokenGroupKey
            }
            Global.openBuyCryptoModalRequested(d.buyFormData)
        }
    }

    Component {
        id: cmpSavedAddresses

        SavedAddressesView {
            rootStore: RootStore
            networkConnectionStore: root.networkConnectionStore
            networksStore: root.networksStore

            onSendToAddressRequested: {
                Global.sendToRecipientRequested(address)
            }
        }
    }

    Component {
        id: cmpFollowingAddresses
        FollowingAddressesView {
            rootStore: RootStore
            contactsStore: root.contactsStore
            networkConnectionStore: root.networkConnectionStore
            networksStore: root.networksStore

            onSendToAddressRequested: {
                Global.sendToRecipientRequested(address)
            }
        }
    }

    Component {
        id: walletContainer

        RightTabView {
            walletRootStore: root.walletRootStore
            sharedRootStore: root.sharedRootStore
            store: root.store
            contactsStore: root.contactsStore
            communitiesStore: root.communitiesStore
            networkConnectionStore: root.networkConnectionStore
            networksStore: root.networksStore

            swapEnabled: root.swapEnabled
            dAppsEnabled: root.dAppsEnabled
            dAppsVisible: root.dAppsVisible

            dAppsModel: root.dAppsModel

            onLaunchShareAddressModal: Global.openShowQRPopup({
                                                                  switchingAccounsEnabled: true,
                                                                  hasFloatingButtons: true
                                                              })
            onLaunchSwapModal: (groupKey) => {
                const params = {
                    selectedAccountAddress: d.getSelectedOrFirstNonWatchedAddress(),
                    selectedNetworkChainId: StatusQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "layer", 1, "chainId"),
                    defaultFromGroupKey: groupKey
                }
                root.openSwapModalRequested(params)
            }
            onDappListRequested: root.dappListRequested()
            onDappConnectRequested: root.dappConnectRequested()
            onDappDisconnectRequested: (dappUrl) =>root.dappDisconnectRequested(dappUrl)
            onLaunchBuyCryptoModal: d.launchBuyCryptoModal()

            onSendTokenRequested: (senderAddress, gorupKey, tokenType) => root.sendTokenRequested(senderAddress, gorupKey, tokenType)

            onManageNetworksRequested: root.manageNetworksRequested()
        }
    }

    StatusSectionLayout {
        id: walletSectionLayout
        navBar: root.navBar
        anchors.fill: parent
        backButtonName: RootStore.backButtonName
        onBackButtonClicked: {
            rightPanelStackView.currentItem.resetStack();
        }

        leftPanel: LeftTabView {
            id: leftTab
            anchors.fill: parent
            emojiPopup: root.emojiPopup
            networkConnectionStore: root.networkConnectionStore
            isKeycardEnabled: root.isKeycardEnabled

            changeSelectedAccount: function(address) {
                walletSectionLayout.goToNextPanel()
                d.displayAddress(address)
            }
            selectAllAccounts: function() {
                walletSectionLayout.goToNextPanel()
                d.displayAllAddresses()
            }
            selectSavedAddresses: function() {
                walletSectionLayout.goToNextPanel()
                d.displaySavedAddresses()
            }
            selectFollowingAddresses: function() {
                walletSectionLayout.goToNextPanel()
                d.displayFollowingAddresses()
            }
        }

        centerPanel: StackView {
            id: rightPanelStackView
            anchors.fill: parent
            anchors.leftMargin: Theme.xlPadding * 2
            anchors.rightMargin: Theme.xlPadding * 2
            initialItem: walletContainer
            replaceEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
            }
            replaceExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.OutCubic }
            }
        }
        headerBackground: AccountHeaderGradient {
            width: parent.width
            overview: RootStore.overview
        }

        footer: WalletFooter {
            id: footer

            readonly property bool isHoldingSelected: {
                if (!rightPanelStackView.currentItem || rightPanelStackView.currentItem.currentTabIndex !== WalletLayout.RightPanelSelection.Collectibles) {
                    return false
                }
                return !!walletStore.currentViewedCollectible && walletStore.currentViewedHoldingTokenGroupKey !== ""
            }
            readonly property bool isCommunityCollectible: !!walletStore.currentViewedCollectible ? walletStore.currentViewedCollectible.communityId !== "" : false
            readonly property bool isOwnerCommunityCollectible: isCommunityCollectible ? (walletStore.currentViewedCollectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner) : false

            visible: anyActionAvailable
            width: parent.width
            height: visible ? implicitHeight: 0
            walletStore: RootStore
            transactionStore: root.transactionStore
            swapEnabled: root.swapEnabled
            networkConnectionStore: root.networkConnectionStore
            isCommunityOwnershipTransfer: footer.isHoldingSelected && footer.isOwnerCommunityCollectible
            communityName: {
                if (selectedCommunityForCollectible.available)
                    return selectedCommunityForCollectible.item.name
                if (isCommunityCollectible)
                    return Utils.compactAddress(walletStore.currentViewedCollectible.communityId, 4)
                return ""
            }

            onLaunchShareAddressModal: Global.openShowQRPopup({
                                                                  switchingAccounsEnabled: true,
                                                                  hasFloatingButtons: true
                                                              })
            onLaunchSendModal: (fromAddress) => {
                                   if(isCommunityOwnershipTransfer) {
                                       const tokenItem = walletStore.currentViewedCollectible
                                       const ownership = StatusQUtils.ModelUtils.get(tokenItem.ownership, 0)

                                       Global.openTransferOwnershipPopup(tokenItem.communityId,
                                                                         footer.communityName,
                                                                         tokenItem.communityImage,
                                                                         {
                                                                             key: tokenItem.tokenId,
                                                                             privilegesLevel: tokenItem.communityPrivilegesLevel,
                                                                             chainId: tokenItem.chainId,
                                                                             name: tokenItem.name,
                                                                             artworkSource: tokenItem.artworkSource,
                                                                             accountAddress: fromAddress,
                                                                             tokenAddress: tokenItem.contractAddress
                                                                         })
                                       return
                                   }

                                   // Common send modal popup:
                                   root.sendTokenRequested(fromAddress,
                                                             walletStore.currentViewedHoldingTokenGroupKey,
                                                             walletStore.currentViewedHoldingType)
                               }
            onLaunchBridgeModal: {
                root.bridgeTokenRequested(walletStore.currentViewedHoldingTokenGroupKey,
                                          walletStore.currentViewedHoldingType)
            }
            onLaunchSwapModal: {
                let params = {
                    selectedAccountAddress: d.getSelectedOrFirstNonWatchedAddress(),
                    selectedNetworkChainId: StatusQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "layer", 1, "chainId"),
                }

                if(!!walletStore.currentViewedHoldingTokenGroupKey && walletStore.currentViewedHoldingType === Constants.TokenType.ERC20) {
                    params.defaultFromGroupKey =  walletStore.currentViewedHoldingTokenGroupKey
                }
                root.openSwapModalRequested(params)
            }
            onLaunchBuyCryptoModal: d.launchBuyCryptoModal()

            ModelEntry {
                id: selectedCommunityForCollectible
                sourceModel: !!footer.walletStore.currentViewedCollectible && footer.isCommunityCollectible ? root.communitiesStore.communitiesList : null
                key: "id"
                value: footer.walletStore.currentViewedCollectible.communityId
            }
        }
    }

    Loader {
        id: keypairImport
        active: false

        sourceComponent: KeypairImportPopup {
            store.keypairImportModule: RootStore.keypairImportModule
        }

        onLoaded: {
            keypairImport.item.open()
        }
    }
}

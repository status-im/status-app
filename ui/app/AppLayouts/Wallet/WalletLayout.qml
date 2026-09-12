import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Layout
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Core.Theme

import utils
import shared.controls
import shared.popups.addaccount
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

    // The section chrome (StatusSectionLayout) is owned by WalletLoader; it is
    // injected here so the existing panel hook-ups keep their call sites.
    property StatusSectionLayout sectionLayout

    // Set by the loader: true once a skeleton is up and nothing is animating,
    // i.e. when a synchronous panel build is safe.
    property bool buildPanelsSync: false

    // --- Back-navigation contract, forwarded to the loader-owned chrome.
    // This Item wrapper would otherwise be a dead-end for AppMain's Link 2 on
    // desktop. See AppMain.tryGoBack().
    function tryGoBack() {
        return root.sectionLayout?.tryGoBack() ?? false
    }
    readonly property bool leftPanelReady: leftPanelLoader.status === Loader.Ready
    readonly property bool centerPanelReady: centerPanelLoader.status === Loader.Ready

    readonly property bool canGoBack: root.sectionLayout?.canGoBack ?? false

    // Consumed by the chrome in WalletLoader
    readonly property string backButtonName: RootStore.backButtonName

    function handleBackButtonClicked() {
        if (d.rightPanelStack?.currentItem && !!d.rightPanelStack.currentItem.resetStack) {
            d.rightPanelStack.currentItem.resetStack()
        }
    }

    // Subsection back history keyed by the selected account. Navigates via
    // d.displayAddress (not changeSelectedAccount, which advances the panel).
    readonly property var subsectionHistory: StatusQUtils.SubsectionNavigationHistory {
        currentKey: RootStore.selectedAddress
        validateFn: (address) => StatusQUtils.ModelUtils.indexOf(RootStore.accounts, "address", address) >= 0
        onNavigateRequested: (address) => d.displayAddress(address)
    }

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
    property bool buyEnabled

    property var dAppsModel

    property bool isKeycardEnabled: true

    signal dappListRequested()
    signal dappConnectRequested()
    signal dappDisconnectRequested(string dappUrl)

    signal manageNetworksRequested()

    // TODO: remove tokenType parameter from signals below
    signal sendTokenRequested(string senderAddress, string groupKey, int tokenType)

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

        function onDisplayAddAccountPopup() {
            addAccount.active = true
        }

        function onDestroyAddAccountPopup() {
            addAccount.active = false
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
            if (d.rightPanelStack?.currentItem)
                d.rightPanelStack.currentItem.currentTabIndex = rightPanelSelection
            else
                d.pendingTabIndex = rightPanelSelection

            let savedAddress = data.savedAddress?? ""
            if (!!savedAddress) {
                RootStore.currentActivityFiltersStore.resetAllFilters()
                RootStore.currentActivityFiltersStore.toggleSavedAddress(savedAddress)
            }
        }

        // In portrait mode, it automatically swipes to the detailed content
        root.sectionLayout?.goToNextPanel()
    }

    QtObject {
        id: d

        // Only the panel the user is looking at is built when the section
        // activates; the other follows once that one is up. Portrait shows one
        // panel at a time so currentIndex names it; landscape shows both and
        // the center panel is the one being read.
        readonly property bool portrait: root.sectionLayout?.isPortrait ?? false
        readonly property int primaryIndex: portrait ? (root.sectionLayout?.currentIndex ?? 1) : 1
        property bool secondaryAllowed: false
        readonly property bool leftWanted: primaryIndex === 0 || secondaryAllowed
        readonly property bool centerWanted: primaryIndex === 1 || secondaryAllowed

        // The center StackView is behind a Loader now, so a navigation request
        // can arrive before it exists. Hold it and replay on load.
        property Component pendingStackComponent: null
        property int pendingTabIndex: -1

        readonly property StackView rightPanelStack: centerPanelLoader.item as StackView

        function replaceRightPanel(cmp) {
            if (rightPanelStack)
                rightPanelStack.replace(cmp)
            else
                pendingStackComponent = cmp
        }

        function flushPendingStackOps() {
            if (pendingStackComponent) {
                rightPanelStack.replace(pendingStackComponent)
                pendingStackComponent = null
            }
            if (pendingTabIndex >= 0) {
                rightPanelStack.currentItem.currentTabIndex = pendingTabIndex
                pendingTabIndex = -1
            }
        }

        readonly property bool showSavedAddresses: RootStore.showSavedAddresses
        onShowSavedAddressesChanged: {
            if(showSavedAddresses) {
                d.replaceRightPanel(cmpSavedAddresses)
                RootStore.backButtonName = ""
            } else if (!showFollowingAddresses) {
                // Only replace with walletContainer if we're not showing following addresses
                d.replaceRightPanel(walletContainer)
                RootStore.backButtonName = ""
            }
        }

        readonly property bool showFollowingAddresses: RootStore.showFollowingAddresses
        onShowFollowingAddressesChanged: {
            if(showFollowingAddresses) {
                d.replaceRightPanel(cmpFollowingAddresses)
                RootStore.backButtonName = ""
            } else if (!showSavedAddresses) {
                // Only replace with walletContainer if we're not showing saved addresses
                d.replaceRightPanel(walletContainer)
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
            RootStore.showFollowingAddresses = true
            RootStore.showSavedAddresses = false
            RootStore.selectedAddress = ""
        }

        function resetRightPanelStackView() {
            if (d.rightPanelStack?.currentItem && !!d.rightPanelStack.currentItem.resetView) {
                d.rightPanelStack.currentItem.resetView()
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
            buyEnabled: root.buyEnabled
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

            onSendTokenRequested: (senderAddress, groupKey, tokenType) => root.sendTokenRequested(senderAddress, groupKey, tokenType)

            onManageNetworksRequested: root.manageNetworksRequested()
        }
    }

    LeftTabViewState {
        id: leftPanelState

        accountsModel: root.walletRootStore.accounts
        selectedAddress: root.walletRootStore.selectedAddress
        showSavedAddresses: root.walletRootStore.showSavedAddresses
        showFollowingAddresses: root.walletRootStore.showFollowingAddresses
        totalCurrencyBalance: root.walletRootStore.totalCurrencyBalance
        balanceLoading: root.walletRootStore.balanceLoading
        accountBalanceNotAvailable: root.networkConnectionStore.accountBalanceNotAvailable
        accountBalanceNotAvailableText: root.networkConnectionStore.accountBalanceNotAvailableText
    }

    // Panels are constructed and wired here, but presented by the loader-owned
    // chrome (LayoutItemProxy targets); they have no visual parent until then.
    readonly property Item leftPanel: Loader {
        id: leftPanelLoader
        // The panel incubates before the chrome adopts it, i.e. with no visual
        // parent, and a Loader reports its item's implicit size as its own.
        // Sized to the slot it is about to land in, nothing leaks upward and
        // the adoption writes no geometry at all - the chrome takes the
        // geometry over the moment it adopts it, so this cannot fight the
        // layout in either orientation.
        width: root.sectionLayout?.leftPanelSlotWidth ?? 0
        height: root.sectionLayout?.leftPanelSlotHeight ?? 0
        asynchronous: !(root.buildPanelsSync && d.primaryIndex === 0)
        active: d.leftWanted
        sourceComponent: leftPanelComponent
        onLoaded: d.secondaryAllowed = true
    }

    Component {
        id: leftPanelComponent

    LeftTabView {
                id: leftTab
                anchors.fill: parent
                viewState: leftPanelState
    
                onAddAccountPopupRequested: root.walletRootStore.runAddAccountPopup()
                onAddWatchOnlyAccountPopupRequested: root.walletRootStore.runAddWatchOnlyAccountPopup()
                onEditAccountPopupRequested: address => root.walletRootStore.runEditAccountPopup(address)
                onWatchAccountHiddenFromTotalBalanceUpdated: (address, hideFromTotalBalance) =>
                    root.walletRootStore.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)
                onAccountDeletionRequested: (address, password) =>
                    root.walletRootStore.deleteAccount(address, password)
                onUserAuthenticationRequested: requestedBy =>
                    root.walletRootStore.authenticateLoggedInUser(requestedBy)
    
                onAccountSelected: address => {
                    root.sectionLayout?.goToNextPanel()
                    d.displayAddress(address)
                }
                onAllAccountsSelected: {
                    root.sectionLayout?.goToNextPanel()
                    d.displayAllAddresses()
                }
                onSavedAddressesSelected: {
                    root.sectionLayout?.goToNextPanel()
                    d.displaySavedAddresses()
                }
                onFollowingAddressesSelected: {
                    root.sectionLayout?.goToNextPanel()
                    d.displayFollowingAddresses()
                }
            }
    }

    readonly property Item centerPanel: Loader {
        id: centerPanelLoader
        // The panel incubates before the chrome adopts it, i.e. with no visual
        // parent, and a Loader reports its item's implicit size as its own.
        // Sized to the slot it is about to land in, nothing leaks upward and
        // the adoption writes no geometry at all - the chrome takes the
        // geometry over the moment it adopts it, so this cannot fight the
        // layout in either orientation.
        width: root.sectionLayout?.centerPanelSlotWidth ?? 0
        height: root.sectionLayout?.centerPanelSlotHeight ?? 0
        asynchronous: !(root.buildPanelsSync && d.primaryIndex === 1)
        active: d.centerWanted
        sourceComponent: centerPanelComponent
        onLoaded: { d.secondaryAllowed = true; d.flushPendingStackOps() }
    }

    Component {
        id: centerPanelComponent

    StackView {
                id: rightPanelStackView
                initialItem: walletContainer
                replaceEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
                }
                replaceExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.OutCubic }
                }
            }
    }
    readonly property Item headerBackground: AccountHeaderGradient {
            width: parent ? parent.width : 0
            overview: RootStore.overview
        }

    readonly property Item footer: WalletFooter {
            id: footer

            visible: anyActionAvailable
            width: parent ? parent.width : 0
            height: visible ? implicitHeight: 0
            walletStore: RootStore
            transactionStore: root.transactionStore
            swapEnabled: root.swapEnabled
            buyEnabled: root.buyEnabled
            networkConnectionStore: root.networkConnectionStore

            onLaunchShareAddressModal: Global.openShowQRPopup({
                                                                  switchingAccounsEnabled: true,
                                                                  hasFloatingButtons: true
                                                              })
            onLaunchSendModal: (fromAddress) => {
                                   root.sendTokenRequested(fromAddress,
                                                             walletStore.currentViewedHoldingTokenGroupKey,
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

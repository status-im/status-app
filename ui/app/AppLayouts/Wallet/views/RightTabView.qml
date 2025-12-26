import QtCore
import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import AppLayouts.Communities.stores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppLayoutsStores

import shared.controls
import shared.panels
import shared.stores as SharedStores
import shared.views
import utils

import QtModelsToolkit
import SortFilterProxyModel

import "./"
import "../stores"
import "../panels"
import "../views/collectibles"

RightTabBaseView {
    id: root

    enum TabIndex {
        Assets = 0,
        Collectibles = 1,
        Activity = 2
    }

    property alias currentTabIndex: walletTabBar.currentIndex

    property WalletStores.RootStore walletRootStore
    property SharedStores.RootStore sharedRootStore
    property AppLayoutsStores.RootStore store
    property AppLayoutsStores.ContactsStore contactsStore
    property CommunitiesStore communitiesStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore

    property bool swapEnabled
    property bool dAppsEnabled
    property bool dAppsVisible
    property var dAppsModel

    signal launchShareAddressModal()
    signal launchBuyCryptoModal()
    signal launchSwapModal(string groupKey)
    signal sendTokenRequested(string senderAddress, string gorupKey, int tokenType)
    signal manageNetworksRequested()

    signal dappListRequested()
    signal dappConnectRequested()
    signal dappDisconnectRequested(string dappUrl)


    onManageNetworksRequested: {
        Global.changeAppSectionBySectionType(Constants.appSection.profile,
                                             Constants.settingsSubsection.wallet,
                                             Constants.walletSettingsSubsection.manageNetworks)
    }

    function resetView() {
        resetStack()
        root.currentTabIndex = 0
    }

    function resetStack() {
        stack.currentIndex = 0;
        RootStore.backButtonName = d.getBackButtonText(stack.currentIndex);
    }

    WalletAccountHeader {
        id: header

        readonly property var overview: root.walletRootStore.overview

        allAccounts: overview.isAllAccounts
        emojiId: SQUtils.Emoji.iconId(overview.emoji ?? "")
        balance: LocaleUtils.currencyAmountToLocaleString(overview.currencyBalance)
        balanceLoading: overview.balanceLoading
        color: Utils.getColorForId(Theme.palette, overview.colorId)
        name: overview.name
        balanceAvailable: !root.networkConnectionStore.accountBalanceNotAvailable
        networksModel: root.networksStore.activeNetworks
        ensOrElidedAddress: RootStore.overview.ens ||
                            SQUtils.Utils.elideAndFormatWalletAddress(
                                RootStore.overview.mixedcaseAddress)
        lastReloadedTime: !!root.walletRootStore.lastReloadTimestamp ?
                              LocaleUtils.formatRelativeTimestamp(
                                  root.walletRootStore.lastReloadTimestamp * 1000) : ""

        tokensLoading: root.walletRootStore.isAccountTokensReloading

        showNetworksNotificationIcon: {
            const newChains = Constants.chains.newChains
            const seenChains = localAppSettings.seenNetworkChains

            for (let i = 0; i < newChains.length; i++)
                if (seenChains.indexOf(newChains[i]) === -1)
                    return true

            return false
        }

        FunctionAggregator {
            id: chainIdsAggregator

            model: SortFilterProxyModel {
                sourceModel: root.networksStore.activeNetworks
                filters: ValueFilter {
                    roleName: "isEnabled"
                    value: true
                }
            }
            initialValue: []
            roleName: "chainId"
            aggregateFunction: (aggr, value) => [...aggr, value]
        }

        Binding on networksSelection {
            value: chainIdsAggregator.value
        }

        dAppsEnabled: root.dAppsEnabled
        dAppsVisible: root.dAppsVisible
        dAppsModel: root.dAppsModel

        onDappListRequested: root.dappListRequested()
        onDappConnectRequested: root.dappConnectRequested()
        onDappDisconnectRequested: (dappUrl) =>root.dappDisconnectRequested(dappUrl)
        onManageNetworksRequested: root.manageNetworksRequested()
        onAddressClicked: root.launchShareAddressModal()
        onToggleNetworkRequested: chainId => root.networksStore.toggleNetworkEnabled(chainId)
        onNetworksShown: {
            if (!showNetworksNotificationIcon)
                return
            let seenChains = JSON.parse(localAppSettings.seenNetworkChains)
            seenChains.push(...Constants.chains.newChains)
            localAppSettings.seenNetworkChains = JSON.stringify(seenChains)
        }
        onReloadRequested: root.walletRootStore.reloadAccountTokens()
    }

    header: stack.currentIndex === 0 ? header : null

    StackLayout {
        id: stack

        onCurrentIndexChanged: {
            RootStore.backButtonName = d.getBackButtonText(currentIndex)
        }

        QtObject {
            id: d
            function getBackButtonText(index) {
                switch(index) {
                case 1:
                    return qsTr("Collectibles")
                case 2:
                    return qsTr("Assets")
                case 3:
                    return qsTr("Activity")
                default:
                    return ""
                }
            }

            readonly property var walletViewsMap: [
                assetsView,
                collectiblesView,
                historyView
            ]

            readonly property var detailedCollectibleActivityController: RootStore.tmpActivityController0
        }

        Settings {
            id: walletSettings
            category: "walletSettings-" + root.contactsStore.myPublicKey
            property real collectiblesViewCustomOrderApplyTimestamp: 0
            property bool buyBannerEnabled: true
            property bool receiveBannerEnabled: true
        }

        Component {
            id: buyReceiveBannerComponent
            BuyReceiveBanner {
                id: banner
                topPadding: anyVisibleItems ? 8 : 0
                bottomPadding: anyVisibleItems ? 20 : 0

                onBuyClicked: root.launchBuyCryptoModal()
                onReceiveClicked: root.launchShareAddressModal()
                buyEnabled: walletSettings.buyBannerEnabled
                receiveEnabled: walletSettings.receiveBannerEnabled
                onCloseBuy: walletSettings.buyBannerEnabled = false
                onCloseReceive: walletSettings.receiveBannerEnabled = false
            }
        }

        Component {
            id: confirmHideCommunityAssetsPopup

            ConfirmHideCommunityAssetsPopup {
                destroyOnClose: true

                required property string communityId

                onConfirmButtonClicked: {
                    RootStore.walletAssetsStore.assetsController.showHideGroup(communityId, false /*hide*/)
                    close();
                }
            }
        }

        // StackLayout.currentIndex === 0
        ColumnLayout {
            spacing: 0

            ImportKeypairInfo {
                Layout.fillWidth: true
                Layout.topMargin: Theme.bigPadding
                Layout.preferredHeight: childrenRect.height
                visible: root.walletRootStore.walletSectionInst.hasPairedDevices
                         && root.walletRootStore.walletSectionInst.keypairOperabilityForObservedAccount === Constants.keypair.operability.nonOperable

                onRunImport: {
                    root.walletRootStore.walletSectionInst.runKeypairImportPopup()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StatusTabBar {
                    id: walletTabBar
                    objectName: "rightSideWalletTabBar"
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding

                    StatusTabButton {
                        objectName: "assetsTabButton"
                        width: implicitWidth
                        text: qsTr("Assets")
                    }
                    StatusTabButton {
                        objectName: "collectiblesTabButton"
                        width: implicitWidth
                        text: qsTr("Collectibles")
                    }
                    StatusTabButton {
                        objectName: "activityTabButton"
                        rightPadding: 0
                        width: implicitWidth
                        text: qsTr("Activity")
                    }
                    onCurrentIndexChanged: {
                        RootStore.setCurrentViewedHoldingType(walletTabBar.currentIndex === 1 ? Constants.TokenType.ERC721 : Constants.TokenType.ERC20)
                    }
                }
                StatusFlatButton {
                    id: filterButton
                    objectName: "filterButton"
                    icon.name: "filter"
                    checkable: true
                    icon.color: checked ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                    Behavior on icon.color { ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                    highlighted: checked
                    visible: walletTabBar.currentIndex !== RightTabView.TabIndex.Activity // TODO #16761: Re-enable filter for activity when implemented
                }
            }

            Loader {
                id: mainViewLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: d.walletViewsMap[walletTabBar.currentIndex]

                Component {
                    id: assetsView

                    AssetsView {
                        AssetsViewAdaptor {
                            id: assetsViewAdaptor

                            accounts: RootStore.addressFilters
                            chains: root.networksStore.networkFilters

                            marketValueThreshold:
                                RootStore.tokensStore.displayAssetsBelowBalance
                                ? RootStore.tokensStore.getDisplayAssetsBelowBalanceThresholdDisplayAmount()
                                : 0

                            Connections {
                                target: RootStore.tokensStore

                                function displayAssetsBelowBalanceThresholdChanged() {
                                    assetsViewAdaptor.marketValueThresholdChanged()
                                }
                            }

                            tokensModel: RootStore.walletAssetsStore.groupedAccountAssetsModel

                            formatBalance: (balance, key) => {
                                return LocaleUtils.currencyAmountToLocaleString(
                                                   RootStore.currencyStore.getCurrencyAmount(balance, key))
                            }

                            chainsError: (chains) => {
                                if (!root.networkConnectionStore)
                                    return ""
                                return root.networkConnectionStore.getBlockchainNetworkDownText(chains)
                            }
                        }

                        function refreshSortSettings() {
                            settings.category = settingsCategoryName
                            walletSettings.sync()
                            settings.sync()
                            let value = SortOrderComboBox.TokenOrderBalance
                            if (walletSettings.assetsViewCustomOrderApplyTimestamp > settings.sortOrderUpdateTimestamp && customOrderAvailable) {
                                value = SortOrderComboBox.TokenOrderCustom
                            } else {
                                value = settings.currentSortValue
                            }
                            sortByValue(value)
                            setSortOrder(settings.currentSortOrder)
                        }

                        function saveSortSettings() {
                            settings.currentSortValue = getSortValue()
                            settings.currentSortOrder = getSortOrder()
                            settings.sortOrderUpdateTimestamp = new Date().getTime()
                            settings.sync()
                        }

                        readonly property string settingsCategoryName: {
                            const addressFilters = RootStore.addressFilters
                            return "AssetsViewSortSettings-" + (addressFilters.indexOf(':') > -1 ? "all" : addressFilters)
                        }
                        onSettingsCategoryNameChanged: {
                            saveSortSettings()
                            refreshSortSettings()
                        }

                        Component.onCompleted: refreshSortSettings()
                        Component.onDestruction: saveSortSettings()

                        readonly property var walletSettings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
                            id: walletSettings
                            category: "walletSettings-" + root.contactsStore.myPublicKey
                            property var assetsViewCustomOrderApplyTimestamp
                        }

                        readonly property var settings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
                            id: settings
                            property int currentSortValue: SortOrderComboBox.TokenOrderDateAdded
                            property var sortOrderUpdateTimestamp
                            property int currentSortOrder: Qt.DescendingOrder
                        }

                        loading: RootStore.overview.balanceLoading
                        sorterVisible: filterButton.checked
                        customOrderAvailable: RootStore.walletAssetsStore.assetsController.hasSettings
                        model: assetsViewAdaptor.model
                        bannerComponent: buyReceiveBannerComponent

                        marketDataError: !!root.networkConnectionStore
                                         ? root.networkConnectionStore.getMarketNetworkDownText()
                                         : ""
                        balanceError: {
                            if (!root.networkConnectionStore)
                                return ""

                            return (root.networkConnectionStore.noBlockchainConnectionAndNoCache
                                    && !root.networkConnectionStore.noMarketConnectionAndNoCache)
                                    ? root.networkConnectionStore.noBlockchainConnectionAndNoCacheText
                                    : ""
                        }

                        formatFiat: balance => RootStore.currencyStore.formatCurrencyAmount(
                                        balance, RootStore.currencyStore.currentCurrency)

                        sendEnabled: root.networkConnectionStore.sendBuyBridgeEnabled &&
                                     !RootStore.overview.isWatchOnlyAccount && RootStore.overview.canSend
                        communitySendEnabled: RootStore.tokensStore.showCommunityAssetsInSend
                        swapEnabled: !RootStore.overview.isWatchOnlyAccount
                        swapVisible: root.swapEnabled

                        onSendRequested: (key) => {
                            root.sendTokenRequested(RootStore.overview.mixedcaseAddress.toLowerCase(),
                                                    key, Constants.TokenType.ERC20)
                        }

                        onSwapRequested: (key) => root.launchSwapModal(key)
                        onReceiveRequested: root.launchShareAddressModal()
                        onCommunityClicked: Global.switchToCommunity(communityKey)

                        onHideRequested: (key) => {
                                             const token = SQUtils.ModelUtils.getByKey(model, "key", key)
                                             Global.openConfirmHideAssetPopup(token.symbol, token.name, token.icon, !!token.communityId)
                                         }
                        onHideCommunityAssetsRequested:
                            (communityKey) => {
                                const community = SQUtils.ModelUtils.getByKey(model, "communityId", communityKey)
                                confirmHideCommunityAssetsPopup.createObject(root, {
                                                                                 name: community.communityName,
                                                                                 icon: community.communityIcon,
                                                                                 communityId: communityKey }
                                                                             ).open()
                            }
                        onManageTokensRequested: Global.changeAppSectionBySectionType(
                                                     Constants.appSection.profile,
                                                     Constants.settingsSubsection.wallet,
                                                     Constants.walletSettingsSubsection.manageAssets)
                        onAssetClicked: (key) => {
                            const tokenGroup = SQUtils.ModelUtils.getByKey(model, "key", key)

                            const firstTokenInGroup = SQUtils.ModelUtils.get(tokenGroup.tokens, 0) // for fetching market data a token key of the first token from the list of grouped tokens can be used, cause they share the same set of data

                            RootStore.tokensStore.getHistoricalDataForToken(firstTokenInGroup.key, RootStore.currencyStore.currentCurrency)

                            assetDetailView.tokenGroup = tokenGroup
                            RootStore.setCurrentViewedHolding(tokenGroup.key, Constants.TokenType.ERC20, tokenGroup.communityId ?? "")
                            stack.currentIndex = 2
                        }
                    }
                }

                Component {
                    id: collectiblesView
                    CollectiblesView {
                        id: collView
                        function refreshSortSettings() {
                            settings.category = settingsCategoryName
                            walletSettings.sync()
                            settings.sync()
                            let value = SortOrderComboBox.TokenOrderBalance
                            if (walletSettings.collectiblesViewCustomOrderApplyTimestamp > settings.sortOrderUpdateTimestamp && customOrderAvailable) {
                                value = SortOrderComboBox.TokenOrderCustom
                            } else {
                                value = settings.currentSortValue
                            }
                            sortByValue(value)
                            setSortOrder(settings.currentSortOrder)
                        }

                        function saveSortSettings() {
                            settings.currentSortValue = getSortValue()
                            settings.currentSortOrder = getSortOrder()
                            settings.sortOrderUpdateTimestamp = new Date().getTime()
                            settings.sync()
                        }

                        readonly property string settingsCategoryName: "CollectiblesViewSortSettings-" + (addressFilters.indexOf(':') > -1 ? "all" : addressFilters)
                        onSettingsCategoryNameChanged: {
                            saveSortSettings()
                            refreshSortSettings()
                        }

                        Component.onCompleted: refreshSortSettings()
                        Component.onDestruction: saveSortSettings()

                        readonly property var settings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
                            id: settings
                            property int currentSortValue: SortOrderComboBox.TokenOrderDateAdded
                            property real sortOrderUpdateTimestamp: 0
                            property alias selectedFilterGroupIds: collView.selectedFilterGroupIds
                            property int currentSortOrder: Qt.DescendingOrder
                        }

                        ownedAccountsModel: RootStore.nonWatchAccounts
                        controller: RootStore.collectiblesStore.collectiblesController
                        activeNetworks: root.networksStore.activeNetworks
                        networkFilters: root.networksStore.networkFilters
                        addressFilters: RootStore.addressFilters
                        sendEnabled: root.networkConnectionStore.sendBuyBridgeEnabled && !RootStore.overview.isWatchOnlyAccount && RootStore.overview.canSend
                        filterVisible: filterButton.checked
                        customOrderAvailable: controller.hasSettings
                        bannerComponent: buyReceiveBannerComponent
                        onCollectibleClicked: function (chainId, contractAddress, tokenId, uid, tokenType, communityId) {
                            RootStore.collectiblesStore.getDetailedCollectible(chainId, contractAddress, tokenId)
                            RootStore.setCurrentViewedHolding(uid, tokenType, communityId)
                            d.detailedCollectibleActivityController.resetFilter()
                            d.detailedCollectibleActivityController.setFilterAddressesJson(JSON.stringify(RootStore.addressFilters.split(":")))
                            d.detailedCollectibleActivityController.setFilterChainsJson(JSON.stringify([chainId]), false)
                            d.detailedCollectibleActivityController.setFilterCollectibles(JSON.stringify([uid]))
                            d.detailedCollectibleActivityController.updateFilter()

                            stack.currentIndex = 1
                        }
                        onSendRequested: function (collectionUid, tokenType, fromAddress) {
                            const collectible = SQUtils.ModelUtils.getByKey(controller.sourceModel, "collectionUid", collectionUid)
                            if (!!collectible && collectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner) {
                                Global.openTransferOwnershipPopup(collectible.communityId,
                                                                  collectible.communityName,
                                                                  collectible.communityImage,
                                                                  {
                                                                      key: collectible.tokenId,
                                                                      privilegesLevel: collectible.communityPrivilegesLevel,
                                                                      chainId: collectible.chainId,
                                                                      name: collectible.name,
                                                                      artworkSource: collectible.communityImage,
                                                                      accountAddress: fromAddress,
                                                                      tokenAddress: collectible.contractAddress
                                                                  })
                                return
                            }

                            root.sendTokenRequested(fromAddress, collectionUid, tokenType)
                        }
                        onReceiveRequested: (symbol) => root.launchShareAddressModal()
                        onSwitchToCommunityRequested: (communityId) => Global.switchToCommunity(communityId)
                        onManageTokensRequested: Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.wallet,
                                                                                      Constants.walletSettingsSubsection.manageCollectibles)
                        isFetching: RootStore.collectiblesStore.areCollectiblesFetching
                        isUpdating: RootStore.collectiblesStore.areCollectiblesUpdating
                        isError: RootStore.collectiblesStore.areCollectiblesError
                    }
                }
                Component {
                    id: historyView
                    HistoryView {
                        overview: RootStore.overview
                        activityStore: RootStore
                        communitiesStore: root.communitiesStore
                        currencyStore: root.sharedRootStore.currencyStore
                        networksStore: root.networksStore
                        showAllAccounts: RootStore.showAllAccounts
                        filterVisible: false  // TODO #16761: Re-enable filter for activity when implemented
                        bannerComponent: buyReceiveBannerComponent
                    }
                }
            }
        }
        CollectibleDetailView {
            id: collectibleDetailView

            visible : (stack.currentIndex === 1)

            collectible: RootStore.collectiblesStore.detailedCollectible
            isCollectibleLoading: RootStore.collectiblesStore.isDetailedCollectibleLoading
            activityModel: d.detailedCollectibleActivityController.model
            addressFilters: RootStore.addressFilters
            rootStore: root.sharedRootStore
            walletRootStore: RootStore
            communitiesStore: root.communitiesStore
            networksStore: root.networksStore

            onVisibleChanged: {
                if (!visible) {
                    RootStore.resetCurrentViewedHolding(Constants.TokenType.ERC721)
                    RootStore.collectiblesStore.resetDetailedCollectible()
                }
            }
        }
        AssetsDetailView {
            id: assetDetailView

            visible: (stack.currentIndex === 2)

            tokensStore: RootStore.tokensStore
            allNetworksModel: root.networksStore.activeNetworks
            address: RootStore.overview.mixedcaseAddress
            currencyStore: RootStore.currencyStore
            networkFilters: root.networksStore.networkFilters

            networkConnectionStore: root.networkConnectionStore

            onVisibleChanged: {
                if (!visible)
                    RootStore.resetCurrentViewedHolding(Constants.TokenType.ERC20)
            }
        }
    }
}

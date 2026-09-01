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
    property bool buyEnabled
    property bool dAppsEnabled
    property bool dAppsVisible
    property var dAppsModel

    signal launchShareAddressModal()
    signal launchBuyCryptoModal()
    signal launchSwapModal(string groupKey)
    signal sendTokenRequested(string senderAddress, string groupKey, int tokenType)
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

        function hasUnseenNewChains(seenChainsJson) {
            const newChains = Constants.chains.newChains
            const seen = JSON.parse(seenChainsJson)
            for (let i = 0; i < newChains.length; i++)
                if (seen.indexOf(newChains[i]) === -1)
                    return true
            return false
        }

        function markNewChainsSeen(seenChainsJson) {
            const seen = JSON.parse(seenChainsJson)
            return JSON.stringify([...seen, ...Constants.chains.newChains])
        }

        showNetworksNotificationIcon: header.hasUnseenNewChains(localAppSettings.seenNetworkChains)
        showManageNetworksNotificationIcon: header.hasUnseenNewChains(localAppSettings.seenManageNetworksChains)

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
        onManageNetworksRequested: {
            if (showManageNetworksNotificationIcon)
                localAppSettings.seenManageNetworksChains = header.markNewChainsSeen(localAppSettings.seenManageNetworksChains)
            root.manageNetworksRequested()
        }
        onAddressClicked: root.launchShareAddressModal()
        onToggleNetworkRequested: chainId => root.networksStore.toggleNetworkEnabled(chainId)
        onNetworksShown: {
            if (showNetworksNotificationIcon)
                localAppSettings.seenNetworkChains = header.markNewChainsSeen(localAppSettings.seenNetworkChains)
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
                    return collectiblesString
                case 2:
                    return assetsString
                case 3:
                    return historyString
                default:
                    return ""
                }
            }

            readonly property string collectiblesString: qsTr("Collectibles")
            readonly property string assetsString: qsTr("Assets")
            readonly property string historyString: qsTr("History")

            readonly property var walletViewsMap: [
                assetsView,
                collectiblesView,
                historyView
            ]

            readonly property var detailedCollectibleActivityController: RootStore.tmpActivityController0
        }

        Settings {
            id: walletSettings
            category: "walletSettings-" + userProfile.pubKey
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
                buyEnabled: walletSettings.buyBannerEnabled && root.buyEnabled
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
                        text: d.assetsString
                    }
                    StatusTabButton {
                        objectName: "collectiblesTabButton"
                        width: implicitWidth
                        text: d.collectiblesString
                    }
                    StatusTabButton {
                        objectName: "activityTabButton"
                        rightPadding: 0
                        width: implicitWidth
                        text: d.historyString
                    }
                    onCurrentIndexChanged: {
                        RootStore.setCurrentViewedHoldingType(walletTabBar.currentIndex === 1 ? Constants.TokenType.ERC721 : Constants.TokenType.ERC20)
                    }
                }
                // Ownership check running in the background. It lives in the tab
                // header, next to the filter button, so that starting/finishing a
                // check never shifts or overlays the list below: the row's height
                // is set by the tab bar and the filter button, and the tab bar
                // simply yields the few pixels it takes.
                StatusLoadingIndicator {
                    objectName: "collectiblesOwnershipCheckIndicator"

                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: Theme.halfPadding
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    color: Theme.palette.baseColor1
                    visible: walletTabBar.currentIndex === RightTabView.TabIndex.Collectibles
                             && RootStore.collectiblesStore.areCollectiblesUpdating

                    StatusToolTip {
                        visible: hoverHandler.hovered
                        text: qsTr("Checking collectibles ownership…")
                    }

                    HoverHandler {
                        id: hoverHandler
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

            // Per-tab skeleton shown while the tab view incubates; takes the
            // loader's layout slot while the loader is hidden. Built from plain
            // LoadingComponent shapes — the real loading delegates
            // (LoadingTokenDelegate & co) are too expensive to create here.
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.padding
                active: mainViewLoader.status !== Loader.Ready
                visible: active
                sourceComponent: {
                    switch (walletTabBar.currentIndex) {
                    case RightTabView.TabIndex.Collectibles:
                        return collectiblesSkeleton
                    case RightTabView.TabIndex.Activity:
                        return activitySkeleton
                    default:
                        return assetsSkeleton
                    }
                }
            }

            Component {
                id: assetsSkeleton

                WalletAssetListSkeleton {}
            }

            // cell metrics mirror CollectiblesView
            Component {
                id: collectiblesSkeleton

                LoadingSkeletonGroup {
                    id: collectiblesSkeletonRoot

                    readonly property bool compact: width < 600
                    readonly property int itemSpacing: compact ? Theme.halfPadding : 0
                    readonly property int cellWidth: compact ? Math.floor(width / 3) : 176
                    readonly property int cellHeight: compact ? cellWidth + 49 : 225

                    Flow {
                        anchors.fill: parent
                        spacing: collectiblesSkeletonRoot.itemSpacing

                        Repeater {
                            model: 6
                            ColumnLayout {
                                width: collectiblesSkeletonRoot.cellWidth - collectiblesSkeletonRoot.itemSpacing
                                height: collectiblesSkeletonRoot.cellHeight - collectiblesSkeletonRoot.itemSpacing
                                spacing: Theme.halfPadding

                                LoadingSkeletonTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radius
                                }
                                LoadingSkeletonTile {
                                    implicitWidth: 90
                                    implicitHeight: 14
                                }
                                LoadingSkeletonTile {
                                    Layout.bottomMargin: Theme.halfPadding
                                    implicitWidth: 60
                                    implicitHeight: 12
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: activitySkeleton

                LoadingSkeletonGroup {
                    ColumnLayout {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: Theme.padding

                        Repeater {
                            model: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                spacing: Theme.padding

                                LoadingSkeletonTile {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: width / 2
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.halfPadding

                                    LoadingSkeletonTile {
                                        implicitWidth: 140
                                        implicitHeight: 14
                                    }
                                    LoadingSkeletonTile {
                                        implicitWidth: 100
                                        implicitHeight: 12
                                    }
                                }
                                LoadingSkeletonTile {
                                    Layout.alignment: Qt.AlignRight
                                    implicitWidth: 70
                                    implicitHeight: 14
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: mainViewLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.padding
                asynchronous: true
                visible: status === Loader.Ready
                sourceComponent: d.walletViewsMap[walletTabBar.currentIndex]

                Component {
                    id: assetsView

                    AssetsView {
                        id: walletAssetsView

                        formatBalance: (balance, key) => {
                            return LocaleUtils.currencyAmountToLocaleString(
                                               RootStore.currencyStore.getCurrencyAmount(balance, key))
                        }

                        chainsError: (chains) => {
                            if (!root.networkConnectionStore)
                                return ""
                            return root.networkConnectionStore.getBlockchainNetworkDownText(chains)
                        }

                        onSortRequested: (roleName, order) => RootStore.walletAssetsStore.sortAssets(roleName, order)

                        function refreshSortSettings() {
                            settings.category = settingsCategoryName
                            walletSettings.sync()
                            settings.sync()
                            if (walletSettings.assetsViewCustomOrderApplyTimestamp > settings.sortOrderUpdateTimestamp && customOrderAvailable) {
                                sortByValue(SortOrderComboBox.TokenOrderCustom)
                                setSortOrder(Qt.AscendingOrder) // same as SortOrderComboBox.onActivated for Custom order
                            } else {
                                sortByValue(settings.currentSortValue)
                                setSortOrder(settings.currentSortOrder)
                            }
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
                            category: "walletSettings-" + userProfile.pubKey
                            property var assetsViewCustomOrderApplyTimestamp
                            onAssetsViewCustomOrderApplyTimestampChanged: walletAssetsView.refreshSortSettings()
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
                        model: RootStore.walletAssetsStore.assetsModel
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

                        sendEnabled: root.networkConnectionStore.walletReadyForTransactionsEnabled &&
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
                                             const token = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.groupedAccountAssetsModel, "key", key)
                                             Global.openConfirmHideAssetPopup(key, token.symbol, token.name, token.logoUri || Constants.tokenIcon(token.symbol, false), !!token.communityId)
                                         }
                        onHideCommunityAssetsRequested:
                            (communityKey) => {
                                const community = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.groupedAccountAssetsModel, "communityId", communityKey)
                                confirmHideCommunityAssetsPopup.createObject(root, {
                                                                                 name: community.communityName,
                                                                                 icon: community.communityImage,
                                                                                 communityId: communityKey }
                                                                             ).open()
                            }
                        onManageTokensRequested: Global.changeAppSectionBySectionType(
                                                     Constants.appSection.profile,
                                                     Constants.settingsSubsection.wallet,
                                                     Constants.walletSettingsSubsection.manageAssets)
                        onAssetClicked: (key) => {
                            const tokenGroup = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.groupedAccountAssetsModel, "key", key)
                            const listAsset = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.assetsModel, "key", key)

                            assetDetailView.tokenGroup = listAsset ? Object.assign({}, tokenGroup, {
                                balance: listAsset.balance,
                                balanceLoading: listAsset.balanceLoading,
                                marketPrice: listAsset.marketPrice,
                                balanceText: LocaleUtils.currencyAmountToLocaleString(
                                    RootStore.currencyStore.getCurrencyAmount(listAsset.balance, key)),
                            }) : tokenGroup
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
                            if (walletSettings.collectiblesViewCustomOrderApplyTimestamp > settings.sortOrderUpdateTimestamp && customOrderAvailable) {
                                sortByValue(SortOrderComboBox.TokenOrderCustom)
                                setSortOrder(Qt.AscendingOrder) // same as SortOrderComboBox.onActivated for Custom order
                            } else {
                                sortByValue(settings.currentSortValue)
                                setSortOrder(settings.currentSortOrder)
                            }
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

                        Connections {
                            target: walletSettings
                            function onCollectiblesViewCustomOrderApplyTimestampChanged() {
                                collView.refreshSortSettings()
                            }
                        }

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
                        unsupportedChainIds: root.networkConnectionStore.unsupportedCollectibleChains
                        sendEnabled: root.networkConnectionStore.walletReadyForTransactionsEnabled && !RootStore.overview.isWatchOnlyAccount && RootStore.overview.canSend
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
                            if (!!collectible &&
                                    (collectible.soulbound ||
                                     collectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner)) {
                                return
                            }

                            root.sendTokenRequested(fromAddress, collectionUid, tokenType)
                        }
                        onReceiveRequested: (key) => root.launchShareAddressModal()
                        onSwitchToCommunityRequested: (communityId) => Global.switchToCommunity(communityId)
                        onManageTokensRequested: Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.wallet,
                                                                                      Constants.walletSettingsSubsection.manageCollectibles)
                        isError: RootStore.collectiblesStore.areCollectiblesError
                    }
                }
                Component {
                    id: historyView
                    HistoryView {
                        objectName: "walletAccountHistoryView"
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

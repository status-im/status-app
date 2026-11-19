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

// Loaded by URL (see RightTabView), so CollectiblesView is not loaded with the wallet section
CollectiblesView {
    id: collView

    required property Item host // RightTabView
    required property QtObject walletSettings // Settings
    required property var detailedCollectibleActivityController

    signal showDetailRequested()

    function refreshSortSettings() {
        settings.category = settingsCategoryName
        collView.walletSettings.sync()
        settings.sync()
        if (collView.walletSettings.collectiblesViewCustomOrderApplyTimestamp > settings.sortOrderUpdateTimestamp && customOrderAvailable) {
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
        target: collView.walletSettings
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
    activeNetworks: collView.host.networksStore.activeNetworks
    networkFilters: collView.host.networksStore.networkFilters
    addressFilters: RootStore.addressFilters
    unsupportedChainIds: collView.host.networkConnectionStore.unsupportedCollectibleChains
    sendEnabled: collView.host.networkConnectionStore.walletReadyForTransactionsEnabled && !RootStore.overview.isWatchOnlyAccount && RootStore.overview.canSend
        customOrderAvailable: controller.hasSettings
        onCollectibleClicked: function (chainId, contractAddress, tokenId, uid, tokenType, communityId) {
        RootStore.collectiblesStore.getDetailedCollectible(chainId, contractAddress, tokenId)
        RootStore.setCurrentViewedHolding(uid, tokenType, communityId)
        collView.detailedCollectibleActivityController.resetFilter()
        collView.detailedCollectibleActivityController.setFilterAddressesJson(JSON.stringify(RootStore.addressFilters.split(":")))
        collView.detailedCollectibleActivityController.setFilterChainsJson(JSON.stringify([chainId]), false)
        collView.detailedCollectibleActivityController.setFilterCollectibles(JSON.stringify([uid]))
        collView.detailedCollectibleActivityController.updateFilter()

        collView.showDetailRequested()
    }
    onSendRequested: function (collectionUid, tokenType, fromAddress) {
        const collectible = SQUtils.ModelUtils.getByKey(controller.sourceModel, "collectionUid", collectionUid)
        if (!!collectible &&
                (collectible.soulbound ||
                 collectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner)) {
            return
        }

        collView.host.sendTokenRequested(fromAddress, collectionUid, tokenType)
    }
    onReceiveRequested: (key) => collView.host.launchShareAddressModal()
    onSwitchToCommunityRequested: (communityId) => Global.switchToCommunity(communityId)
    onManageTokensRequested: Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.wallet,
                                                                  Constants.walletSettingsSubsection.manageCollectibles)
    isError: RootStore.collectiblesStore.areCollectiblesError
}

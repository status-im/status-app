import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Market.stores

import mainui.sectionLoaders

Loader {
    id: root

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property SharedStores.CurrenciesStore currencyStore
    required property MarketStore marketStore

    required property HandlersManagerLoader popupHandler

    property real leftPanelWidthOverride: 0

    asynchronous: false

    QtObject {
        id: d

        readonly property url realUrl: QmlCompiler.marketUrl
        readonly property url privacyWallUrl: QmlCompiler.marketPrivacyWallUrl
        readonly property url targetUrl: root.rootStore.thirdpartyServicesEnabled ? realUrl : privacyWallUrl
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(d.targetUrl))
        loadSection()
    }

    function loadSection() {
        if (!active)
            return
        if (!!item && root.source === d.targetUrl)
            return
        if (d.targetUrl === d.privacyWallUrl) {
            setSource(d.targetUrl, {})
            return
        }

        setSource(d.targetUrl, {
            objectName:             "marketLayout",
            visible:                false,
            tokensModel:            Qt.binding(() => root.marketStore.marketLeaderboardModel),
            totalTokensCount:       Qt.binding(() => root.marketStore.totalLeaderboardCount),
            loading:                Qt.binding(() => root.marketStore.marketLeaderboardLoading),
            swapEnabled:            Qt.binding(() => root.featureFlagsStore.swapEnabled),
            currentPage:            Qt.binding(() => root.marketStore.currentPage),
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
            currencySymbol:         Qt.binding(() => {
                const symbol = SQUtils.ModelUtils.getByKey(root.currencyStore.currenciesModel,
                                                            "shortName",
                                                            root.currencyStore.currentCurrency,
                                                            "symbol")
                return !!symbol ? symbol : ""
            }),
            fnFormatCurrencyAmount: function(amount, options) {
                return root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency, options)
            },
        })
    }

    onActiveChanged: {
        if (!active && root.rootStore.thirdpartyServicesEnabled)
            marketStore.unsubscribeFromUpdates()
        loadSection()
    }
    onLoaded: {
        item.anchors.fill = root
        if (item.resetView)
            item.resetView()

        item.visible = true
        
        if (root.rootStore.thirdpartyServicesEnabled)
            root.marketStore.requestMarketTokenPage(1, item.pageSize)
    }

    Connections {
        target: root.rootStore
        function onThirdpartyServicesEnabledChanged() { root.loadSection() }
    }

    Connections {
        target: root.item

        function onRequestLaunchSwap() {
            root.popupHandler.launchSwap()
        }
        function onFetchMarketTokens(pageNumber, pageSize) {
            root.marketStore.requestMarketTokenPage(pageNumber, pageSize)
        }
        function onOpenThirdpartyServicesInfoPopupRequested() {
            root.popupHandler.openThirdpartyServicesPopup()
        }
        function onOpenDiscussPageRequested() {
            Global.requestOpenLink(Constants.statusDiscussPageUrl)
        }
    }
}

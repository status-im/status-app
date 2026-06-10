import QtQml
import QtQuick

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

Loader {
    id: root

    // Stores — only what WalletLayout / WalletPrivacyWall consume
    required property AppStores.RootStore rootStore
    required property AppStores.ContactsStore contactsStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    required property CommunitiesStore communitiesStore
    required property TransactionStore transactionStore

    // App-shell handlers / shared loaders
    required property HandlersManagerLoader popupHandler
    required property Loader dappsServiceLoader
    required property Loader emojiPopupLoader

    property bool appMainVisible: false
    property real leftPanelWidthOverride: 0

    asynchronous: false

    QtObject {
        id: d

        readonly property url realUrl: QmlCompiler.walletUrl
        readonly property url privacyWallUrl: QmlCompiler.walletPrivacyWallUrl
        readonly property url targetUrl: rootStore.thirdpartyServicesEnabled ? realUrl : privacyWallUrl
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(d.targetUrl))
        root.loadSection()
    }

    function loadSection() {
         if (!root.active)
            return
        if (!!root.item && root.source === d.targetUrl)
            return

        if (d.targetUrl === d.privacyWallUrl) {
            setSource(d.privacyWallUrl, {})
            return
        }

        setSource(d.realUrl, {
            visible:                false,
            objectName:             "walletLayoutReal",
            walletRootStore:        WalletStores.RootStore,
            sharedRootStore:        Qt.binding(() => root.sharedRootStore),
            store:                  Qt.binding(() => root.rootStore),
            contactsStore:          Qt.binding(() => root.contactsStore),
            communitiesStore:       Qt.binding(() => root.communitiesStore),
            transactionStore:       Qt.binding(() => root.transactionStore),
            emojiPopup:             Qt.binding(() => root.emojiPopupLoader.item),
            networkConnectionStore: Qt.binding(() => root.networkConnectionStore),
            networksStore:          Qt.binding(() => root.networksStore),
            appMainVisible:         Qt.binding(() => root.appMainVisible),
            swapEnabled:            Qt.binding(() => root.featureFlagsStore.swapEnabled),
            buyEnabled:             Qt.binding(() => root.featureFlagsStore.buyEnabled),
            dAppsVisible:           Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.serviceAvailableToCurrentAddress
                                            : false),
            dAppsEnabled:           Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.isServiceOnline
                                            : false),
            dAppsModel:             Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.dappsModel
                                            : null),
            isKeycardEnabled:       Qt.binding(() => root.featureFlagsStore.keycardEnabled),
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: {
        if (!root.active) {
            WalletStores.RootStore.showSavedAddresses = false
            WalletStores.RootStore.showFollowingAddresses = false
            WalletStores.RootStore.selectedAddress = ""
        }
        loadSection()
    }
    onLoaded: {
        if (root.item.resetView)
            root.item.resetView()
        root.item.visible = true
    }

    Connections {
        target: root.rootStore
        function onThirdpartyServicesEnabledChanged() { root.loadSection() }
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onDappConnectRequested() {
            root.dappsServiceLoader.dappConnectRequested()
        }
        function onDappDisconnectRequested(dappUrl) {
            root.dappsServiceLoader.dappDisconnectRequested(dappUrl)
        }
        function onSendTokenRequested(senderAddress, groupKey, tokenType) {
            root.popupHandler.sendToken(senderAddress, groupKey, tokenType)
        }
        function onOpenSwapModalRequested(swapFormData) {
            root.popupHandler.launchSwapSpecific(swapFormData)
        }
        function onOpenThirdpartyServicesInfoPopupRequested() {
            root.popupHandler.openThirdpartyServicesPopup()
        }
        function onOpenDiscussPageRequested() {
            Global.requestOpenLink(Constants.statusDiscussPageUrl)
        }
    }
}

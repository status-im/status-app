import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

Loader {
    id: root

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.ProfileStore profileStore
    required property ProfileStores.AdvancedStore advancedStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.CurrenciesStore currencyStore
    required property TransactionStore transactionStore

    required property HandlersManagerLoader popupHandler

    property real leftPanelWidthOverride: 0

    asynchronous: false

    QtObject {
        id: d

        readonly property url realUrl: QmlCompiler.browserUrl
        readonly property url privacyWallUrl: QmlCompiler.browserPrivacyWallUrl
        readonly property url targetUrl: rootStore.thirdpartyServicesEnabled ? realUrl : privacyWallUrl

        // Holder for the per-load store instances; rebuilt on each privacy-wall toggle.
        property QtObject storeParent: null
    }

    Component { id: bookmarksStoreComp; BrowserStores.BookmarksStore {} }
    Component { id: downloadsStoreComp; BrowserStores.DownloadsStore {} }
    Component { id: browserRootStoreComp; BrowserStores.BrowserRootStore {} }
    Component { id: browserWalletStoreComp; BrowserStores.BrowserWalletStore {} }
    Component { id: browserActivityStoreComp; BrowserStores.BrowserActivityStore {} }
    Component { id: browserPreferencesStoreComp; BrowserStores.BrowserPreferencesStore {} }
    Component { id: storeParentComp; QtObject {} }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(d.targetUrl))
        loadSection()
    }

    function loadSection() {
        if (!root.active)
            return

        if (!!root.item && root.source === d.targetUrl)
            return

        if (d.storeParent) {
            d.storeParent.destroy()
            d.storeParent = null
        }

        if (d.targetUrl === d.privacyWallUrl) {
            setSource(d.targetUrl, {})
            return
        }

        d.storeParent = storeParentComp.createObject(root)
        const browserWalletStore = browserWalletStoreComp.createObject(d.storeParent)
        const browserActivityStore = browserActivityStoreComp.createObject(d.storeParent, {
            browserWalletStore: browserWalletStore,
        })
        const bookmarksStore = bookmarksStoreComp.createObject(d.storeParent)
        const downloadsStore = downloadsStoreComp.createObject(d.storeParent)
        const browserRootStore = browserRootStoreComp.createObject(d.storeParent)
        const browserPreferencesStore = browserPreferencesStoreComp.createObject(d.storeParent)

        setSource(d.targetUrl, {
            isMobile:                   SQUtils.Utils.isMobile,
            visible:                    false,
            bookmarksStore:             bookmarksStore,
            downloadsStore:             downloadsStore,
            browserRootStore:           browserRootStore,
            browserPreferencesStore:    browserPreferencesStore,
            browserWalletStore:         browserWalletStore,
            browserActivityStore:       browserActivityStore,
            userUID:                    Qt.binding(() => root.profileStore.pubKey),
            thirdpartyServicesEnabled:  Qt.binding(() => root.rootStore.thirdpartyServicesEnabled),
            dappsEnabled:               Qt.binding(() => root.featureFlagsStore.dappsEnabled),
            currencyStore:              Qt.binding(() => root.currencyStore),
            networksStore:              Qt.binding(() => root.networksStore),
            connectorController:        Qt.binding(() => WalletStores.RootStore.dappsConnectorController),
            isDebugEnabled:             Qt.binding(() => root.advancedStore.isDebugEnabled),
            transactionStore:           Qt.binding(() => root.transactionStore),
            leftPanelWidthOverride:     Qt.binding(() => root.leftPanelWidthOverride),
            "anchors.fill":             root,
        })
    }

    onActiveChanged: {
        if (root.active) {
            loadSection()
            return
        }
        if (d.storeParent) {
            d.storeParent.destroy()
            d.storeParent = null
        }
    }
    onLoaded: item.visible = true

    Connections {
        target: root.rootStore
        function onThirdpartyServicesEnabledChanged() { root.loadSection() }
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onSendToRecipientRequested(address) {
            root.popupHandler.sendToRecipient(address)
        }
        function onOpenThirdpartyServicesInfoPopupRequested() {
            root.popupHandler.openThirdpartyServicesPopup()
        }
        function onOpenDiscussPageRequested() {
            Global.openLinkWithConfirmation(Constants.statusDiscussPageUrl,
                                            SQUtils.StringUtils.extractDomainFromLink(Constants.statusDiscussPageUrl))
        }
    }
}

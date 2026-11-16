import QtQml
import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Browser.webview

StatusSectionLoader {
    id: root

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.AdvancedStore advancedStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.CurrenciesStore currencyStore
    required property TransactionStore transactionStore

    required property HandlersManagerLoader popupHandler

    /// The Browser section is the current one.
    property bool sectionCurrent: false

    /// Whether the layout should exist. Mobile gives it back when inactive
    /// (BrowserDropPolicy); desktop keeps it from the first visit on.
    readonly property bool keepLoaded: SQUtils.Utils.isMobile ? dropPolicy.keepLoaded
                                                              : d.visited || sectionCurrent

    asynchronous: false

    BrowserDropPolicy {
        id: dropPolicy

        // Inactive (a system sheet on top) is still in front; Suspended is not.
        shown: root.sectionCurrent && (Qt.application.state === Qt.ApplicationActive
                                       || Qt.application.state === Qt.ApplicationInactive)
        hasLivePage: root.item?.hasLivePage ?? false
        keepAlive: root.item?.keepAlive ?? false

        onDropIdleViewsRequested: {
            console.info("[Browser] Drop: idle Web Views (a Keep-alive reason holds the layout)")
            root.item?.dropIdleTabs?.()
        }
        onDropping: {
            root.item?.captureSession?.()
            root.item?.terminateRenderers?.()
            console.info("[Browser] Drop: Tabs kept in memory:", d.sessionCache.tabs.length)
        }
        onKeepLoadedChanged: console.info("[Browser] Drop: layout", keepLoaded ? "kept" : "dropped")
        onShownChanged: if (shown) root.item?.resumeCurrentTab?.()
    }

    Connections {
        target: SystemUtils
        function onMemoryPressure() { dropPolicy.memoryPressure() }
    }

    onSectionCurrentChanged: if (sectionCurrent) d.visited = true

    QtObject {
        id: d

        readonly property url realUrl: QmlCompiler.browserUrl
        readonly property url privacyWallUrl: QmlCompiler.browserPrivacyWallUrl
        readonly property url targetUrl: rootStore.thirdpartyServicesEnabled ? realUrl : privacyWallUrl

        // Holder for the per-load store instances; rebuilt on each privacy-wall toggle.
        property QtObject storeParent: null

        property bool visited: false

        // The Tab set and back/forward histories across layout unloads.
        readonly property QtObject sessionCache: QtObject {
            property var tabs: []
            property int currentIndex: 0
        }
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
            setSource(d.targetUrl, {
                          userUID:                    root.userUID,
                          sectionName:                root.sectionName,
                      })
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
        downloadsStore.preferencesStore = browserPreferencesStore
        downloadsStore.restoreDownloadHistory()

        setSource(d.targetUrl, {
            isMobile:                   SQUtils.Utils.isMobile,
            visible:                    false,
            userUID:                    root.userUID,
            sectionName:                root.sectionName,
            bookmarksStore:             bookmarksStore,
            downloadsStore:             downloadsStore,
            browserRootStore:           browserRootStore,
            browserPreferencesStore:    browserPreferencesStore,
            browserWalletStore:         browserWalletStore,
            browserActivityStore:       browserActivityStore,
            thirdpartyServicesEnabled:  Qt.binding(() => root.rootStore.thirdpartyServicesEnabled),
            dappsEnabled:               Qt.binding(() => root.featureFlagsStore.dappsEnabled),
            currencyStore:              Qt.binding(() => root.currencyStore),
            networksStore:              Qt.binding(() => root.networksStore),
            connectorController:        Qt.binding(() => WalletStores.RootStore.dappsConnectorController),
            isDebugEnabled:             Qt.binding(() => root.advancedStore.isDebugEnabled),
            transactionStore:           Qt.binding(() => root.transactionStore),
            leftPanelWidthOverride:     Qt.binding(() => root.leftPanelWidthOverride),
            sessionCache:               d.sessionCache,
            "anchors.fill":             root,
        })
    }

    onActiveChanged: {
        if (root.active) {
            loadSection()
            return
        }
        // Otherwise reactivation rebuilds the layout from the old initial
        // properties, i.e. the stores destroyed below.
        root.source = ""
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

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Layout
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared.popups.send
import shared.stores.send
import shared.stores as SharedStores

import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Wallet.services.dapps

import AppLayouts.Browser.adapters
import AppLayouts.Browser.provider.qml
import AppLayouts.Browser.popups
import AppLayouts.Browser.controls
import AppLayouts.Browser.views
import AppLayouts.Browser.panels
import AppLayouts.Browser.webview

// Code based on https://code.qt.io/cgit/qt/qtwebengine.git/tree/examples/webengine/quicknanobrowser/BrowserWindow.qml?h=5.15
// Licensed under BSD
StatusSectionLayout {
    id: root

    required property bool isMobile
    required property string userUID
    required property bool thirdpartyServicesEnabled
    required property bool dappsEnabled

    required property TransactionStore transactionStore

    required property BrowserStores.BookmarksStore bookmarksStore
    required property BrowserStores.DownloadsStore downloadsStore
    required property BrowserStores.BrowserPreferencesStore browserPreferencesStore
    required property BrowserStores.BrowserRootStore browserRootStore
    required property BrowserStores.BrowserWalletStore browserWalletStore
    required property BrowserStores.BrowserActivityStore browserActivityStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.CurrenciesStore currencyStore
    required property var connectorController

    property bool isDebugEnabled: false
    property string platformOS: Qt.platform.os

    readonly property string userAgent: browserConfig.httpUserAgent

    signal sendToRecipientRequested(string address)

    function openUrlInNewTab(url, initialTitle, activate=false) {
        Qt.callLater(() => _internal.addNewTab(root.browserRootStore.determineRealURL(url), initialTitle, activate))
    }

    function reloadCurrentTab() {
        webViewContext.reloadCurrent()
    }

    // Drive the current tab from Storybook / automation (web content is not in AX).
    function runJsOnCurrentTab(script, callback) {
        const wv = _internal.currentWebView
        if (!wv || typeof wv.runJavaScript !== "function")
            return
        if (typeof wv.ensureLoaded === "function")
            wv.ensureLoaded()
        wv.runJavaScript(script, callback)
    }

    function clearSiteDataOnCurrentTab() {
        webViewContext.clearSiteDataCurrent()
    }

    function clearBrowsingDataOnCurrentTab() {
        webViewContext.clearBrowsingDataCurrent()
        root.downloadsStore.clearDownloadHistory()
    }

    function applyIncognitoMode(checked) {
        webViewContext.setIncognitoCurrent(checked)
        if (!checked && root.connectorController)
            root.connectorController.deleteEphemeralDApps()
    }

    function saveBrowserSession() {
        savedSessionContext.saveSession()
    }
    // Innermost Back tier: the current tab's web history. StatusSectionLayout
    // tries this before the view tier and the tab (subsection) tier.
    contentHistory: QtObject {
        readonly property bool canGoBack: _internal.currentWebView?.canGoBack ?? false

        function tryGoBack() {
            if (!canGoBack)
                return false
            webViewContext.goBackCurrent()
            return true
        }
    }

    // Subsection back history: each tab keyed by the webview's stable `uid`
    // (indices shift when tabs close).
    subsectionHistory: SQUtils.SubsectionNavigationHistory {
        id: tabHistory
        currentKey: _internal.currentWebView ? _internal.currentWebView.uid : ""
        validateFn: (uid) => {
            for (let i = 0; i < tabs.count; i++) {
                const wv = webViewContext.getWebView(i)
                if (wv && wv.uid === uid)
                    return true
            }
            return false
        }
        onNavigateRequested: (uid) => {
            for (let i = 0; i < tabs.count; i++) {
                const wv = webViewContext.getWebView(i)
                if (wv && wv.uid === uid) {
                    tabs.activateTab(i)
                    return
                }
            }
        }
    }

    Component.onCompleted: {
        savedSessionContext.restoreSession()
        // Session-restore tab churn must not be treated as user navigation.
        tabHistory.clear()
    }

    Component.onDestruction: {
        saveBrowserSession()
    }

    Connections {
        target: tabs
        function onCountChanged() {
            savedSessionContext.scheduleSaveSession()
        }
        function onCurrentIndexChanged() {
            savedSessionContext.scheduleSaveSession()
        }
    }

    Connections {
        target: _internal.currentWebView
        function onScrollPositionChanged() {
            const delta = _internal.currentWebView.scrollPosition.y - _internal.lastScrollPos
            _internal.scrolledUp = delta < 0
            _internal.lastScrollPos = _internal.currentWebView.scrollPosition.y
        }
    }

    Connections {
        target: typeof browserSection !== "undefined" ? browserSection : null
        function onOpenUrl(url: string) {
            root.openUrlInNewTab(url);
        }
    }

    QtObject {
        id: _internal

        readonly property Item currentWebView: webViewContext.currentWebView
        readonly property bool currentTabIncognito: currentWebView?.offTheRecord ?? false
        readonly property bool currentTabLoading: currentWebView?.loading ?? false
        property real lastScrollPos: 0
        property bool scrolledUp: true

        function resetScroll() {
            _internal.lastScrollPos = _internal.currentWebView?.scrollPosition.y ?? 0
            _internal.scrolledUp = true
        }

        /// Open a Download Record menu right-aligned with the ⋮ it was invoked from.
        /// x/y stay bound: the menu's width is 0 until its content is first laid out.
        function anchorRecordMenu(menu, anchor, above) {
            menu.parent = anchor
            menu.x = Qt.binding(() => anchor.width - menu.width)
            menu.y = Qt.binding(() => above ? -menu.height : anchor.height)
            menu.open()
        }

        /// Long-press on a link/image (mobile Backends): menu at the touch point,
        /// Download link routed through the host view's Backend (ADR 0005).
        function openLinkContextMenu(linkUrl, imageUrl, position, hostView) {
            linkContextMenuInst.linkUrl = linkUrl
            linkContextMenuInst.imageUrl = imageUrl
            linkContextMenuInst.hostView = hostView
            // position is view-local; the host view fills webStackView.
            linkContextMenuInst.parent = webStackView
            linkContextMenuInst.x = position.x
            linkContextMenuInst.y = position.y
            linkContextMenuInst.open()
        }

        property Component jsDialogComponent: JSDialogWindow {}

        readonly property bool currentTabSupportsFindInPage: currentWebView?.supportsFindInPage ?? false
        readonly property bool hasNativeFindPanel: currentWebView?.hasNativeFindPanel ?? false

        function showFindBar() {
            if (!currentTabSupportsFindInPage)
                return
            if (hasNativeFindPanel)
                currentWebView?.showFindPanel()
            else {
                findBar.visible = true
                findBar.forceActiveFocus()
            }
            // Mobile: Find XOR Download Pill strip (browser-downloads-ux 05).
            if (root.isMobile)
                downloadsContext.setFindUiActive(true)
        }

        function hideFindBar() {
            if (hasNativeFindPanel)
                currentWebView?.hideFindPanel()
            else {
                findBar.visible = false
                findBar.focus = false
            }
            // QML FindBar syncs via onVisibleChanged; native panel has no dismiss
            // signal, so clear Find XOR here when we dismiss it ourselves.
            if (root.isMobile && hasNativeFindPanel)
                downloadsContext.setFindUiActive(false)
        }

        function openDownloadsOverview() {
            onOpenTabsBookmarksOverviewRequested(TabsBookmarksOverviewModal.Mode.Downloads)
        }

        function syncDownloadStripVisibility() {
            downloadsContext.syncStripVisibility()
        }

        function addNewTab(url, initialTitle, activate) {
            var tab = webViewContext.createEmptyTab(tabs.count !== 0 ? currentWebView.profileParams : browserConfig.defaultProfileParams, false, true, url, initialTitle);
            if (activate)
                browserToolbarLoader.activateAddressBar()
            return tab;
        }

        function addNewEmptyTab() {
            addNewTab("", "", true)
        }

        function onRequestLaunchInBrowser(url) {
            if (localAccountSensitiveSettings.useBrowserEthereumExplorer !== Constants.browserEthereumExplorerNone && url.startsWith("0x")) {
                webViewContext.setCurrentWebUrl(root.browserRootStore.get0xFormedUrl(localAccountSensitiveSettings.useBrowserEthereumExplorer, url))
                return
            }
            if (localAccountSensitiveSettings.selectedBrowserSearchEngineId !== SearchEnginesConfig.browserSearchEngineNone && !Utils.isURL(url) && !Utils.isURLWithOptionalProtocol(url)) {
                webViewContext.setCurrentWebUrl(root.browserRootStore.getFormedUrl(localAccountSensitiveSettings.selectedBrowserSearchEngineId, url))
                return
            } else if (Utils.isURLWithOptionalProtocol(url)) {
                url = "https://" + url
            }
            webViewContext.setCurrentWebUrl(url);
        }

        function onRequestOpenDapp(url) {
            if (currentWebView) {
                webViewContext.setCurrentWebUrl(url)
            }
        }

        function onOpenTabsBookmarksOverviewRequested(mode) {
            const tabsCount = tabs.count
            var tabsModel = []

            for (let i = 0; i < tabsCount; i++){
                const webView = webViewContext.getWebView(i)
                if (!!webView) {
                    tabsModel.push({
                                       url: root.browserRootStore.determineRealURL(webView.url.toString()),
                                   })
                }
            }

            downloadsContext.refreshMissingFiles()
            tabsBookmarksOverviewComp.createObject(root, {
                                                       tabsModel,
                                                       currentTabIndex: tabs.currentIndex,
                                                       initialMode: mode,
                                                       // Live binding — snapshot would miss Retry / new Downloads while open.
                                                       downloadsModel: Qt.binding(() => root.downloadsStore.downloadsListModel),
                                                       statusTextFn: (record) => root.downloadsStore.statusText(record),
                                                       elideFileNameFn: (name, maxChars) => root.downloadsStore.elideFileName(name, maxChars)
                                                   }).open()
        }

        function openFavoriteModal(editMode = false, url = "", name = "") {
            const ogUrl = url || (favoritesContext.currentTabIsBookmark ? favoritesContext.currentViewBookmarkEntry.item.url
                                                                        : favoritesContext.currentUrl)
            const ogName = name || (favoritesContext.currentTabIsBookmark ? favoritesContext.currentViewBookmarkEntry.item.name
                                                                          : favoritesContext.currentTitle)
            const params = {editMode, ogUrl, ogName}

            addFavoriteModal.createObject(root, params).open()
        }

        function openFavoriteMenu(parent, pos, url, name) {
            favoriteMenu.createObject(root, {url, name}).popup(parent, pos)
        }

        onCurrentWebViewChanged: {
            findBar.reset()
            // MobileWebView has no native-find dismiss signal; clear Find XOR on tab change.
            if (root.isMobile)
                downloadsContext.setFindUiActive(false)
            _internal.resetScroll()
        }
    }

    invertedLayout: height > width
    showFooter: false
    // Download Pill strip sits flush against the web content, like the mobile one.
    footerSpacing: 0
    headerPadding: 0
    backgroundColor: Theme.palette.statusAppNavBar.backgroundColor

    BrowserFavoritesContext {
        id: favoritesContext
        currentWebView: _internal.currentWebView
        bookmarksStore: root.bookmarksStore
        shouldShowFavoritesBar: localAccountSensitiveSettings.shouldShowFavoritesBar
    }

    BrowserDialogsContext {
        id: dialogsContext
        networksStore: root.networksStore
        browserActivityStore: root.browserActivityStore
        browserWalletStore: root.browserWalletStore
        jsDialogComponent: _internal.jsDialogComponent
        dialogParent: root
    }

    BrowserDownloadsContext {
        id: downloadsContext
        downloadsStore: root.downloadsStore
        getWebViewFn: (index) => webViewContext.getWebView(index)
        getTabsCountFn: () => tabs.count
        removeViewFn: (index) => webViewContext.removeView(index)
        setFooterVisibleFn: (visible) => root.showFooter = visible
        hideFindUiFn: () => _internal.hideFindBar()
        openUrlFn: (url) => root.openUrlInNewTab(url)
        supportsPdfFn: () => !!(_internal.currentWebView && _internal.currentWebView.supportsPdfViewer)
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                downloadsContext.refreshMissingFiles()
        }
    }

    BrowserWebViewContext {
        id: webViewContext
        savedSessionContext: savedSessionContext
        thirdpartyServicesEnabled: root.thirdpartyServicesEnabled
        isDebugEnabled: root.isDebugEnabled
        isMobile: SQUtils.Utils.isMobile // non-UI, do not override with root.isMobile
        hasPopups: SQUtils.Utils.hasPopups(root.Overlay.overlay.children)
        browserSettings: localAccountSensitiveSettings
        connectorController: root.dappsEnabled ? root.connectorController : null
        dappsEnabled: root.dappsEnabled
        hostStackLayout: webStackView
        tabsModel: tabs
        defaultProfileParams: browserConfig.defaultProfileParams
        otrProfileParams: browserConfig.otrProfileParams
        bookmarksStore: root.bookmarksStore
        downloadsStore: root.downloadsStore
        isBrowsableLocalUrlFn: (url) => downloadsContext.isBrowsableLocalUrl(url)
        determineRealURLFn: (url) => root.browserRootStore.determineRealURL(url)
        downloadRequestHandler: (download, hostView) => downloadsContext.handleDownloadRequest(download, hostView)
        linkLongPressHandler: (linkUrl, imageUrl, position, hostView) =>
            _internal.openLinkContextMenu(linkUrl, imageUrl, position, hostView)
        sslErrorHandler: (error) => {
                             error.defer()
                             sslDialog.enqueue(error)
                         }
        jsDialogHandler: (request) => dialogsContext.openJsDialog(request)
        findTextFinishedHandler: function(result) {
            if (!_internal.hasNativeFindPanel) {
                findBar.numberOfMatches = result.numberOfMatches
                findBar.activeMatch = result.activeMatch
            }
        }
    }

    BrowserSavedSessionContext {
        id: savedSessionContext
        webViewContext: webViewContext
        tabs: tabs
        defaultProfileParams: browserConfig.defaultProfileParams
        determineRealURL: (u) => root.browserRootStore.determineRealURL(u)
        preferencesStore: root.browserPreferencesStore
        currentWebView: _internal.currentWebView
    }

    headerContent: ColumnLayout {
        spacing: 0

        BrowserTabView {
            id: tabs

            Layout.fillWidth: true
            Layout.preferredHeight: tabHeight

            savedSessionContext: savedSessionContext
            isMobile: root.isMobile
            currentTabIncognito: _internal.currentTabIncognito
            determineRealURL: function(url) {
                return root.browserRootStore.determineRealURL(url)
            }
            onOpenNewTabTriggered: _internal.addNewEmptyTab()
            fnGetWebView: (index) => {
                              return webViewContext.getWebView(index)
                          }
            onRemoveView: (index) => {
                              webViewContext.removeView(index)
                          }
        }

        Loader {
            id: browserToolbarLoader
            Layout.fillWidth: true
            sourceComponent: root.invertedLayout ? browserPortraitToolbar : browserLandscapeToolbar

            function activateAddressBar() {
                _internal.resetScroll()
                if (root.invertedLayout)
                    mobileAddressBar.activateAddressBar()
                else
                    item.activateAddressBar()
                Qt.callLater(() => {
                                 if (!InputMethod.visible)
                                     InputMethod.show()
                             })
            }

            Connections {
                target: browserToolbarLoader.item ?? null

                function onRequestGoBack() {
                    webViewContext.goBackCurrent()
                }
                function onRequestGoForward() {
                    webViewContext.goForwardCurrent()
                }
                function onRequestReloadPage() {
                    webViewContext.reloadCurrent()
                }
                function onRequestStopLoadingPage() {
                    webViewContext.stopCurrent()
                }
                function onRequestOpenDapp(url) {
                    _internal.onRequestOpenDapp(url)
                }
                function onRequestDisconnectDapp(dappUrl) {
                    webViewContext.disconnectDapp(dappUrl)
                }
                function onAddBookmarkRequested() {
                    const currentUrl = favoritesContext.currentUrl
                    if (!currentUrl) {
                        _internal.openFavoriteModal()
                    } else {
                        root.bookmarksStore.addBookmark(currentUrl, favoritesContext.currentTitle)
                    }
                }
                function onEditBookmarkRequested() {
                    _internal.openFavoriteModal(true)
                }
                function onRemoveBookmarkRequested() {
                    const url = favoritesContext.currentUrl
                    if (url.toString() === "") {
                        return console.error("Can't remove empty bookmark")
                    }
                    root.bookmarksStore.deleteBookmark(url)
                }
                function onRequestLaunchInBrowser(url) {
                    _internal.onRequestLaunchInBrowser(url)
                }
                function onRequestWalletMenu() {
                    dialogsContext.openWalletMenu(browserWalletMenu)
                }
                function onRequestAllOpenTabsView() {
                    _internal.onOpenTabsBookmarksOverviewRequested(TabsBookmarksOverviewModal.Mode.OpenTabs)
                }
                function onOpenSettingMenu(target, pos) {
                    if (root.isMobile)
                        mobileSettingsMenu.open()
                    else
                        settingsMenu.popup(target, pos)
                }
                function onRequestSearch() {
                    browserToolbarLoader.activateAddressBar()
                }
                function onGoIncognito(checked) {
                    root.applyIncognitoMode(checked)
                }
                function onGoBackOrForwardRequested(offset) {
                    webViewContext.goBackOrForwardCurrent(offset)
                }
            }
        }

        Component {
            id: browserLandscapeToolbar
            BrowserLandscapeToolbar {
                url: root.browserRootStore.obtainAddress(_internal.currentWebView?.url ?? "")
                canGoBack: _internal.currentWebView?.canGoBack ?? false
                canGoForward: _internal.currentWebView?.canGoForward ?? false

                isMobile: root.isMobile
                openTabsCount: tabs.count
                currentTabIncognito: _internal.currentTabIncognito
                currentTabIsBookmark: favoritesContext.currentTabIsBookmark
                currentTabLoading: _internal.currentTabLoading
                browserDappsModel: browserDappsProvider.model
                historyModel: _internal.currentWebView?.history?.items ?? null
            }
        }

        Component {
            id: browserPortraitToolbar
            BrowserPortraitToolbar {
                canGoBack: _internal.currentWebView?.canGoBack ?? false
                canGoForward: _internal.currentWebView?.canGoForward ?? false

                isMobile: root.isMobile
                openTabsCount: tabs.count
                currentTabIncognito: _internal.currentTabIncognito
                currentTabIsBookmark: favoritesContext.currentTabIsBookmark
                currentTabLoading: _internal.currentTabLoading
                browserDappsModel: browserDappsProvider.model
                historyModel: _internal.currentWebView?.history?.items ?? null
            }
        }

        Loader {
            id: favoritesBarLoader
            Layout.fillWidth: true
            Layout.preferredHeight: active ? 38: 0
            active: favoritesContext.favoritesBarActive
            sourceComponent: FavoritesBar {
                currentTabIncognito: _internal.currentTabIncognito
                bookmarkModel: root.bookmarksStore.bookmarksModel
                onSetAsCurrentWebUrl: url => webViewContext.setCurrentWebUrl(url)
                onOpenInNewTab: url => root.openUrlInNewTab(url)
                onAddBookmarkRequested: _internal.openFavoriteModal()
                onFavMenuRequested: (parent, pos, url, name) => _internal.openFavoriteMenu(parent, pos, url, name)
            }
        }
    }

    footer: Loader {
        id: footerLoader
        // Desktop: same Download Pill strip as mobile, at the bottom (browser-downloads-ux 04).
        // Mobile hosts the strip under the address bar instead.
        sourceComponent: !root.isMobile ? downloadPillStrip : null
    }

    centerPanel: ColumnLayout {
        id: mainView
        spacing: 0

        MobileAddressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: _internal.scrolledUp ? implicitHeight : 0
            Behavior on Layout.preferredHeight { NumberAnimation {duration: ThemeUtils.AnimationDuration.Fast} }
            id: mobileAddressBar
            visible: root.invertedLayout
            url: root.browserRootStore.obtainAddress(_internal.currentWebView?.url ?? "")
            currentTabLoading: _internal.currentTabLoading
            incognitoMode: _internal.currentTabIncognito
            browserDappsModel: browserDappsProvider.model
            faviconUrl: _internal.currentWebView?.icon ?? ""

            onRequestReloadPage: webViewContext.reloadCurrent()
            onRequestStopLoadingPage: webViewContext.stopCurrent()
            onRequestLaunchInBrowser: url => {
                                          _internal.onRequestLaunchInBrowser(url)
                                          deactivateAddressBar()
                                      }
            onRequestOpenDapp: url => _internal.onRequestOpenDapp(url)
            onRequestDisconnectDapp: dappUrl => webViewContext.disconnectDapp(dappUrl)
            onRequestWalletMenu: dialogsContext.openWalletMenu(browserWalletMenu)
        }

        // Mobile Download Pill strip under the address bar (session-only; not History).
        // Lives in the column so page content shrinks instead of being covered.
        Loader {
            id: mobileDownloadStripLoader
            Layout.fillWidth: true
            Layout.preferredHeight: active && item ? item.implicitHeight : 0
            active: root.isMobile && root.showFooter
            sourceComponent: downloadPillStrip
        }

        FindBar {
            id: findBar
            visible: false

            Layout.fillWidth: true
            Layout.preferredHeight: tabs.tabHeight

            onFindNext: {
                if (text)
                    webViewContext.findTextCurrent(text)
                else if (!visible)
                    _internal.showFindBar()
            }
            onFindPrevious: {
                if (text)
                    webViewContext.findTextCurrent(text, true)
                else if (!visible)
                    _internal.showFindBar()
            }
            onVisibleChanged: {
                if (!visible)
                    webViewContext.findTextCurrent("") // reset the highlight
                // QML FindBar path (Android / desktop): keep Find XOR in sync when
                // the bar is dismissed without going through hideFindBar().
                if (root.isMobile && !_internal.hasNativeFindPanel)
                    downloadsContext.setFindUiActive(visible)
            }
        }

        StackLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            id: webStackView
            currentIndex: tabs.currentIndex
            visible: !overlayLoader.active
        }

        // Overlay for EmptyWebPage (no URL). Downloads List lives in Open tabs only.
        Loader {
            Layout.fillHeight: true
            Layout.fillWidth: true
            id: overlayLoader

            readonly property int contentMode: webViewContext.currentContentMode
            visible: active
            active: contentMode === BrowserWebViewContext.ContentMode.EmptyContent
            sourceComponent: emptyPageComponent
        }
    }

    StatusBubble {
        id: statusBubble
        z: centerPanel.z + 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
    }

    Connections {
        target: _internal.currentWebView
        function onLinkHovered(hoveredUrl) {
            statusBubble.show(hoveredUrl)
        }
    }

    // Non UI component
    Loader {
        // Only load the shortcuts when the browser is visible, to avoid interfering with other app sections
        active: root.visible
        sourceComponent: BrowserShortcutActions {
            currentWebView: _internal.currentWebView
            isMobile: SQUtils.Utils.isMobile
            onActivateAddressBar: browserToolbarLoader.activateAddressBar()
            onHideFindBar: _internal.hideFindBar()
            onFindNextRequested: findBar.findNext()
            onFindPreviousRequested: findBar.findPrevious()
            onZoomIn: webViewContext.changeZoomCurrent(0.1)
            onZoomOut: webViewContext.changeZoomCurrent(-0.1)
            onResetZoomFactor: webViewContext.resetZoomCurrent()
            onNextTabRequested: tabs.activateNextTab()
            onPreviousTabRequested: tabs.activatePreviousTab()
            onRemoveViewRequested: webViewContext.removeView(tabs.currentIndex || 0)
        }
    }

    Component {
        id: emptyPageComponent
        EmptyWebPage {
            bookmarksModel: root.bookmarksStore.bookmarksModel
            determineRealURLFn: function(url) {
                return root.browserRootStore.determineRealURL(url)
            }
            onSetCurrentWebUrl: (url) => webViewContext.setCurrentWebUrl(url)
            onAddBookmarkRequested: _internal.openFavoriteModal()
            onFavMenuRequested: (parent, pos, url, name) => _internal.openFavoriteMenu(parent, pos, url, name)
            Component.onCompleted: {
                // Add fav button at the end of the grid
                var index = root.bookmarksStore.getBookmarkIndexByUrl(Constants.newBookmark)
                if (index !== -1) { root.bookmarksStore.deleteBookmark(Constants.newBookmark) }
                root.bookmarksStore.addBookmark(Constants.newBookmark, qsTr("Add bookmark"))
            }
        }
    }

    Component  {
        id: browserWalletMenu
        BrowserWalletMenu {
            parent: root.invertedLayout ? mobileAddressBar : browserToolbarLoader
            x: parent.width - width - Theme.halfPadding
            y: parent.height + 4

            incognitoMode: _internal.currentTabIncognito
            accounts: root.browserWalletStore.accounts
            currentAccount: root.browserWalletStore.dappBrowserAccount
            activityStore: root.browserActivityStore
            currencyStore: root.currencyStore
            networksStore: root.networksStore

            onSendTriggered: (address) => root.sendToRecipientRequested(address)
            onAccountChanged: (newAddress) => webViewContext.changeAccountForCurrentDapp(newAddress)
            onReload: {
                for (let i = 0; i < tabs.count; ++i){
                    webViewContext.getWebView(i).reload();
                }
            }

            onAccountSwitchRequested: address => root.browserWalletStore.switchAccountByAddress(address)
            onFilterAddressesChangeRequested: addressesJson => root.browserActivityStore.activityController.setFilterAddressesJson(addressesJson)

            Connections {
                target: root.browserActivityStore.transactionActivityStatus
                enabled: visible
                function onIsFilterDirtyChanged() {
                    root.browserActivityStore.updateTransactionFilterIfDirty()
                }
                function onFilterChainsChanged() {
                    root.browserActivityStore.currentActivityFiltersStore.updateCollectiblesModel()
                    root.browserActivityStore.currentActivityFiltersStore.updateRecipientsModel()
                }
            }
        }
    }

    BrowserSettingsMenu {
        id: settingsMenu

        parent: browserToolbarLoader
        modal: true
        dim: false

        incognitoMode: _internal.currentTabIncognito
        zoomFactor: _internal.currentWebView?.zoomFactor ?? 1
        browserSettings: localAccountSensitiveSettings
        clearingBrowsingData: _internal.currentWebView?.clearing ?? false
        clearSiteDataSupported: _internal.currentWebView?.clearSiteDataSupported ?? true
        onForceReload: webViewContext.forceReloadCurrent()
        onClearSiteData: webViewContext.clearSiteDataCurrent()
        onClearBrowsingData: {
            webViewContext.clearBrowsingDataCurrent()
            root.downloadsStore.clearDownloadHistory()
        }
        onAddNewTab: _internal.addNewEmptyTab()
        onOpenDownloads: _internal.openDownloadsOverview()
        onGoIncognito: (checked) => root.applyIncognitoMode(checked)
        onZoomIn: webViewContext.changeZoomCurrent(0.1)
        onZoomOut: webViewContext.changeZoomCurrent(-0.1)
        onResetZoomFactor: webViewContext.resetZoomCurrent()
        onLaunchFindBar: _internal.showFindBar()
        onToggleCompatibilityMode: (checked) => webViewContext.setCompatibilityMode(checked)
        onLaunchBrowserSettings: {
            Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.browserSettings);
        }
    }

    MobileSettingsMenu {
        id: mobileSettingsMenu

        supportsIncognito: _internal.currentWebView?.supportsIncognito ?? false
        incognitoMode: _internal.currentTabIncognito

        supportsZoom: _internal.currentWebView?.supportsZoom ?? false
        zoomFactor: _internal.currentWebView?.zoomFactor ?? 1
        onZoomIn: webViewContext.changeZoomCurrent(0.1)
        onZoomOut: webViewContext.changeZoomCurrent(-0.1)
        onResetZoomFactor: webViewContext.resetZoomCurrent()

        supportsFind: _internal.currentTabSupportsFindInPage
        onLaunchFindBar: _internal.showFindBar()

        clearSiteDataSupported: _internal.currentWebView?.clearSiteDataSupported ?? false
        clearing: _internal.currentWebView?.clearing ?? false
        compatibilityMode: localAccountSensitiveSettings.compatibilityMode
        onForceReload: webViewContext.forceReloadCurrent()
        onClearSiteData: webViewContext.clearSiteDataCurrent()
        onClearBrowsingData: {
            webViewContext.clearBrowsingDataCurrent()
            root.downloadsStore.clearDownloadHistory()
        }
        onToggleCompatibilityMode: (checked) => webViewContext.setCompatibilityMode(checked)

        onGoIncognito: checked => root.applyIncognitoMode(checked)
        onSettingsRequested: Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.browserSettings)
    }

    Component {
        id: tabsBookmarksOverviewComp
        TabsBookmarksOverviewModal {
            getTitleFn: function(tabIndex) {
                const webView = webViewContext.getWebView(tabIndex)
                return savedSessionContext.displayTitle(webView, false)
            }
            getFaviconFn: function(tabIndex) {
                const webView = webViewContext.getWebView(tabIndex)
                if (!webView)
                    return Assets.svg("globe")

                const icon = savedSessionContext.displayIcon(webView)
                return root.browserRootStore.determineRealURL(icon || Assets.svg("globe"))
            }
            getWebViewScreenshot: function (tabIndex, targetImage) {
                const webView = webViewContext.getWebView(tabIndex)
                if (!webView)
                    return ""

                function grabImage() {
                    savedSessionContext.snapshotPersister.grabSnapshot(webView, result => {
                        if (result && result.url)
                            targetImage.source = result.url
                    })
                }

                function grabImageWhenLoaded() {
                    if (webView.htmlPageLoaded)
                        grabImage()
                }

                const isCurrentTab = tabIndex === currentTabIndex
                if (!isCurrentTab) {
                    const cached = browserPreferencesStore.getSnapshot(webView.uid)
                    if (cached) {
                        targetImage.source = cached
                        return ""
                    }
                }

                if (webView.htmlPageLoaded)
                    grabImage()
                else
                    webView.htmlPageLoadedChanged.connect(grabImageWhenLoaded)
            }
            bookmarksModel: root.bookmarksStore.bookmarksModel

            onActivateTabRequested: tabIndex => tabs.activateTab(tabIndex)
            onAddTabRequested: _internal.addNewEmptyTab()
            onEditBookmarkRequested: (url, name) => _internal.openFavoriteModal(true, url, name)
            onDeleteBookmarkRequested: url => root.bookmarksStore.deleteBookmark(url)
            onBookmarkClicked: url => root.openUrlInNewTab(url)

            onDownloadClicked: function (listIndex) {
                const list = root.downloadsStore.downloadsListNewestFirst()
                const record = list[listIndex]
                if (!record)
                    return
                const modelIndex = root.downloadsStore.downloadModel.indexOf(record)
                if (modelIndex < 0)
                    return
                const complete = record.state === AbstractWebView.DownloadState.DownloadCompleted
                if (downloadsContext.openDownloadFromList(complete, modelIndex))
                    close()
            }
            onDownloadOptionsClicked: function (listIndex, anchor) {
                const list = root.downloadsStore.downloadsListNewestFirst()
                const record = list[listIndex]
                if (!record)
                    return
                const modelIndex = root.downloadsStore.downloadModel.indexOf(record)
                if (modelIndex < 0)
                    return
                downloadsContext.populateRecordMenu(downloadListMenuInst, record, modelIndex)
                _internal.anchorRecordMenu(downloadListMenuInst, anchor, false)
            }
        }
    }

    Component {
        id: addFavoriteModal
        AddFavoriteModal {
            incognitoMode: _internal.currentTabIncognito
            onAddBookmarkRequested: (url, name) => root.bookmarksStore.addBookmark(url, name)
            onEditBookmarkRequested: (oldUrl, newUrl, newName) => root.bookmarksStore.updateBookmark(oldUrl, newUrl, newName)
            onDeleteBookmarkRequested: url => root.bookmarksStore.deleteBookmark(url)
            destroyOnClose: true
        }
    }

    StatusMessageDialog {
        id: sslDialog

        property var certErrors: []
        icon: StatusMessageDialog.StandardIcon.Warning
        standardButtons: Dialog.No | Dialog.Yes
        title: qsTr("Server's certificate not trusted")
        text: qsTr("Do you wish to continue?")
        detailedText: qsTr("If you wish so, you may continue with an unverified certificate. Accepting an unverified certificate means you may not be connected with the host you tried to connect to.\nDo you wish to override the security check and continue?")
        onAccepted: {
            certErrors.shift().acceptCertificate();
            presentError();
        }
        onRejected: {
            certErrors.shift().rejectCertificate();
            presentError();
        }
        function enqueue(error){
            certErrors.push(error);
            presentError();
        }
        function presentError(){
            visible = certErrors.length > 0
        }
    }

    BrowserLinkContextMenu {
        id: linkContextMenuInst

        property var hostView: null

        onOpenInNewTabRequested: targetUrl => root.openUrlInNewTab(targetUrl)
        onShareUrlRequested: targetUrl => root.downloadsStore.shareUrlString(targetUrl)
        onDownloadRequested: function (targetUrl) {
            // downloadUrl (not navigation): renderable media would play in the tab
            // instead of saving; the Backend path always raises downloadRequested.
            const view = hostView || _internal.currentWebView
            if (view && view.downloadUrl)
                view.downloadUrl(targetUrl, "")
        }
    }

    DownloadRecordMenu {
        id: downloadListMenuInst
        onShowInFolderRequested: index => root.downloadsStore.openDirectory(index)
        onShareFileRequested: index => downloadsContext.shareFileRecord(root.downloadsStore.getDownload(index))
        onShareUrlRequested: index => downloadsContext.shareUrlRecord(root.downloadsStore.getDownload(index))
        onOpenInBrowserRequested: index => downloadsContext.openInBrowserRecord(root.downloadsStore.getDownload(index))
        onRetryRequested: index => downloadsContext.retryRecord(root.downloadsStore.getDownload(index))
    }

    DownloadRecordMenu {
        id: downloadPillMenuInst
        onDismissRequested: function (index) {
            root.downloadsStore.dismissFromStrip(index)
            _internal.syncDownloadStripVisibility()
        }
        onShowInFolderRequested: index => {
            root.downloadsStore.openDirectoryForRecord(
                        root.downloadsStore.getStripDownload(index))
        }
        onShareFileRequested: index => downloadsContext.shareFileRecord(root.downloadsStore.getStripDownload(index))
        onShareUrlRequested: index => downloadsContext.shareUrlRecord(root.downloadsStore.getStripDownload(index))
        onOpenInBrowserRequested: index => downloadsContext.openInBrowserRecord(root.downloadsStore.getStripDownload(index))
        onRetryRequested: index => downloadsContext.retryRecord(root.downloadsStore.getStripDownload(index))
    }

    Component {
        id: favoriteMenu
        FavoriteMenu {
            onOpenInNewTab: url => root.openUrlInNewTab(url)
            onEditBookmarkRequested: (url, name) => _internal.openFavoriteModal(true /*editMode*/, url, name)
            onDeleteBookmarkRequested: url => root.bookmarksStore.deleteBookmark(url)
            onClosed: destroy()
        }
    }

    BrowserConfig {
        id: browserConfig

        userUID: root.userUID
        featureEnabled: root.dappsEnabled
        httpUserAgent: {
            if (localAccountSensitiveSettings.compatibilityMode) {
                // Google doesn't let you connect if the user agent is Chrome-ish and doesn't satisfy some sort of hidden requirement
                const os = root.platformOS
                let platform = "X11; Linux x86_64" // default Linux
                let mobile = ""
                if (os === SQUtils.Utils.windows)
                    platform = "Windows NT 11.0; Win64; x64"
                else if (os === SQUtils.Utils.mac)
                    platform = "Macintosh; Intel Mac OS X 10_15_7"
                else if (os === SQUtils.Utils.android) {
                    platform = "Linux; Android 10; K"
                    mobile = "Mobile"
                } else if (os === SQUtils.Utils.ios) {
                    platform = "iPhone; CPU iPhone OS 18_6 like Mac OS X"
                    mobile = "Mobile/15E148"
                }

                return "Mozilla/5.0 (%1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 %2 Safari/604.1".arg(platform).arg(mobile)
            }
            return ""
        }
    }

    BCBrowserDappsProvider {
        id: browserDappsProvider
        connectorController: root.dappsEnabled ? root.connectorController : null
        clientId: webViewContext.currentClientId
        clientIdFilter: clientId
    }

    Component {
        id: downloadPillStrip
        DownloadPillStrip {
            downloadsModel: root.downloadsStore.downloadStripModel
            elideFileNameFn: (name, maxChars) => root.downloadsStore.elideFileName(name, maxChars)
            statusTextFn: (record) => root.downloadsStore.statusText(record)
            onOpenDownloadClicked: function (index) {
                downloadsContext.handlePillClicked(index)
            }
            onOptionsClicked: function (index, anchor) {
                const record = root.downloadsStore.getStripDownload(index)
                downloadsContext.populateRecordMenu(downloadPillMenuInst, record, index, { showDismiss: true })
                // Mobile strip is under the address bar → menu below.
                // Desktop strip is the window footer → menu above.
                _internal.anchorRecordMenu(downloadPillMenuInst, anchor, !root.isMobile)
            }
            onClose: {
                // Hide strip only — in-progress pills stay in the session model.
                // Reappears when the next download starts (setFooterVisibleFn).
                root.showFooter = false
            }
        }
    }
}

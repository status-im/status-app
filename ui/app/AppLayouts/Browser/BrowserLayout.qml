import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
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
    required property BrowserStores.BrowserRootStore browserRootStore
    required property BrowserStores.BrowserWalletStore browserWalletStore
    required property BrowserStores.BrowserActivityStore browserActivityStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.CurrenciesStore currencyStore
    required property var connectorController

    property bool isDebugEnabled: false
    property string platformOS: Qt.platform.os

    signal sendToRecipientRequested(string address)

    function openUrlInNewTab(url) {
        var tab = _internal.addNewTab()
        tab.url = root.browserRootStore.determineRealURL(url)
    }

    function reloadCurrentTab() {
        webViewContext.reloadCurrent()
    }

    Component.onCompleted: {
        var tab = webViewContext.createEmptyTab(connectorBridge.defaultProfileParams, true);
        // For Devs: Uncomment the next line if you want to use the simpledapp on first load
        // tab.url = root.browserRootStore.determineRealURL("https://simpledapp.eth");
    }

    Connections {
        target: _internal.currentWebView
        function onUrlChanged() {
            _internal.onCurrentTabUrlChanged()
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
        property bool webViewHidden: false

        property Component jsDialogComponent: JSDialogWindow {}

        function addNewDownloadTab() {
            webViewContext.createDownloadTab(tabs.count !== 0 ? currentWebView.profileParams : connectorBridge.defaultProfileParams);
            tabs.currentIndex = tabs.count - 1;
        }

        function addNewTab() {
            var tab = webViewContext.createEmptyTab(tabs.count !== 0 ? currentWebView.profileParams : connectorBridge.defaultProfileParams);
            browserToolbarLoader.activateAddressBar()
            return tab;
        }

        onCurrentWebViewChanged: {
            onCurrentTabUrlChanged()
            findBar.reset()
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

        function onCurrentTabUrlChanged() {
            const rawUrl = _internal.currentWebView?.url ?? ""

            if (!rawUrl)
                return

            // Update ConnectorBridge with current dApp metadata
            if (_internal.currentWebView && rawUrl) {
                connectorBridge.connectorManager.updateDAppUrl(
                            rawUrl,
                            _internal.currentWebView.title,
                            _internal.currentWebView.icon
                            )
            }
        }

        function onRequestOpenDapp(url) {
            if (currentWebView) {
                webViewContext.setCurrentWebUrl(url)
            }
        }
    }

    invertedLayout: height > width && width <= 600
    showFooter: invertedLayout
    headerPadding: 0
    backgroundColor: Theme.palette.statusAppNavBar.backgroundColor

    BrowserFavoritesContext {
        id: favoritesContext
        currentWebView: _internal.currentWebView
        bookmarksStore: root.bookmarksStore
        shouldShowFavoritesBar: localAccountSensitiveSettings.shouldShowFavoritesBar
        openPopupFn: (popup, params) => Global.openPopup(popup, params)
        addFavoriteModal: addFavoriteModal
    }

    BrowserDialogsContext {
        id: dialogsContext
        networksStore: root.networksStore
        browserActivityStore: root.browserActivityStore
        browserWalletStore: root.browserWalletStore
        openPopupFn: (popup, params) => Global.openPopup(popup, params)
        jsDialogComponent: _internal.jsDialogComponent
        dialogParent: root
    }

    BrowserDownloadsContext {
        id: downloadsContext
        downloadsStore: root.downloadsStore
        tabsModel: tabs
        getWebViewFn: (index) => webViewContext.getWebView(index)
        removeViewFn: (index) => webViewContext.removeView(index)
        setFooterVisibleFn: (visible) => root.showFooter = visible
    }

    // TODO: move this to a single browser header qml file
    headerContent: ColumnLayout {
        spacing: 0

        BrowserTabView {
            id: tabs

            Layout.fillWidth: true
            Layout.preferredHeight: tabHeight

            isMobile: root.isMobile
            currentTabIncognito: _internal.currentTabIncognito
            determineRealURL: function(url) {
                return root.browserRootStore.determineRealURL(url)
            }
            onOpenNewTabTriggered: _internal.addNewTab()
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
                if (root.invertedLayout)
                    footerLoader.item.activateAddressBar()
                else
                    item.activateAddressBar()
            }

            Connections {
                target: browserToolbarLoader.item ?? null

                function onRequestHistoryPopup() {
                    dialogsContext.openHistoryMenu(historyMenu)
                }
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
                    connectorBridge.disconnect(dappUrl)
                }
                function onAddBookmarkRequested() {
                    favoritesContext.openAddFavoritePopup(favoritesContext.currentTabIsBookmark)
                }
                function onRequestLaunchInBrowser(url) {
                    _internal.onRequestLaunchInBrowser(url)
                }
                function onRequestWalletMenu() {
                    dialogsContext.openWalletMenu(browserWalletMenu)
                }
                function onRequestAllOpenTabsView() {
                    // TODO: Launch All Tabs view
                    // https://github.com/status-im/status-app/issues/19569
                }
                function onOpenSettingMenu(target) {
                    dialogsContext.openSettingsMenu(settingsMenu)
                }
                function onRequestSearch() {
                    browserToolbarLoader.activateAddressBar()
                }
                function onGoIncognito(checked) {
                    webViewContext.setIncognitoCurrent(checked)
                }
                function onRequestDownloadsView() {
                    _internal.addNewDownloadTab()
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
                currentTabLoading: _internal.currentWebView?.loading ?? false
                currentTabIsDownloads: webStackView.children[tabs.currentIndex]?.isDownloadView ?? false
                browserDappsModel: browserDappsProvider.model
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
                currentTabLoading: _internal.currentWebView?.loading ?? false
                currentTabIsDownloads: webStackView.children[tabs.currentIndex]?.isDownloadView ?? false
                browserDappsModel: browserDappsProvider.model
            }
        }

        // TODO will be reworked as part of a dedicated Favorites popup (https://github.com/status-im/status-app/issues/19575)
        // Loader {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: active ? 38: 0
        //     active: localAccountSensitiveSettings.shouldShowFavoritesBar &&
        //                       root.bookmarksStore.bookmarksModel.ModelCount.count > 0
        //     sourceComponent: FavoritesBar {
        //         currentTabIncognito: _internal.currentTabIncognito
        //         bookmarkModel: root.bookmarksStore.bookmarksModel
        //         favoritesMenu: favoriteMenu
        //         onSetAsCurrentWebUrl: (url) => _internal.currentWebView.url = _internal.determineRealURL(url)
        //         onOpenInNewTab: (url) => root.openUrlInNewTab(url)
        //         onAddFavModalRequested: {
        //             Global.openPopup(addFavoriteModal, {toolbarMode: true,
        //                                  ogUrl: _internal.currentViewBookmarkEntry.item ? _internal.currentViewBookmarkEntry.item.url : _internal.currentWebView.url,
        //                                  ogName: _internal.currentViewBookmarkEntry.item ? _internal.currentViewBookmarkEntry.item.name : _internal.currentWebView.title})
        //         }
        //     }
        // }

        FindBar {
            id: findBar
            visible: false

            Layout.preferredWidth: 400
            Layout.preferredHeight: tabs.tabHeight
            Layout.alignment: Qt.AlignRight
            z: 60

            onFindNext: {
                if (text)
                    webViewContext.findTextCurrent(text)
                else if (!visible)
                    visible = true;
            }
            onFindPrevious: {
                if (text)
                    webViewContext.findTextCurrent(text, true)
                else if (!visible)
                    visible = true;
            }
            onVisibleChanged: if (!visible) _internal.currentWebView?.findText("") // reset the highlight
        }
    }

    footer: Loader {
        id: footerLoader
        sourceComponent: root.invertedLayout ? mobileAddressBar : downloadBar
    }

    Component {
        id: mobileAddressBar
        MobileAddressBar {
            url: root.browserRootStore.obtainAddress(_internal.currentWebView?.url ?? "")
            currentTabLoading: _internal.currentWebView?.loading ?? false
            incognitoMode: _internal.currentTabIncognito
            browserDappsModel: browserDappsProvider.model
            faviconImage: _internal.currentWebView?.icon?.toString().replace("image://favicon/", "") ?? ""

            onRequestReloadPage: webViewContext.reloadCurrent()
            onRequestStopLoadingPage: webViewContext.stopCurrent()
            onRequestLaunchInBrowser: url => _internal.onRequestLaunchInBrowser(url)
            onRequestOpenDapp: url => _internal.onRequestOpenDapp(url)
            onRequestDisconnectDapp: dappUrl => connectorBridge.disconnect(dappUrl)
            onRequestWalletMenu: dialogsContext.openWalletMenu(browserWalletMenu)
        }
    }

    BrowserWebViewContext {
        id: webViewContext
        thirdpartyServicesEnabled: root.thirdpartyServicesEnabled
        isDebugEnabled: root.isDebugEnabled
        isMobile: root.isMobile
        browserSettings: localAccountSensitiveSettings
        webChannel: connectorBridge.channel
        hostStackLayout: webStackView
        tabsModel: tabs
        defaultProfileParams: connectorBridge.defaultProfileParams
        bookmarksStore: root.bookmarksStore
        downloadsStore: root.downloadsStore
        determineRealURLFn: (url) => root.browserRootStore.determineRealURL(url)
        downloadRequestHandler: (download) => downloadsContext.handleDownloadRequest(download)
        sslErrorHandler: (error) => {
            error.defer()
            sslDialog.enqueue(error)
        }
        jsDialogHandler: (request) => dialogsContext.openJsDialog(request)
        findTextFinishedHandler: (result) => {
            if (!findBar.visible)
                findBar.visible = true
            findBar.numberOfMatches = result.numberOfMatches
            findBar.activeMatch = result.activeMatch
        }
    }

    centerPanel: ColumnLayout {
        id: mainView
        spacing: 0
        StackLayout {
            id: webStackView
            currentIndex: tabs.currentIndex
            visible: !_internal.webViewHidden

            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // Overlay for DownloadView and EmptyWebPage
        Loader {
            anchors.fill: parent
            z: 53

            readonly property int contentMode: webViewContext.currentContentMode

            active: contentMode !== BrowserWebViewContext.ContentMode.WebContent
            sourceComponent: contentMode === BrowserWebViewContext.ContentMode.DownloadContent
                             ? downloadViewComponent
                             : emptyPageComponent
        }
    }

    // Non UI component
    Loader {
        // Only load the shortcuts when the browser is visible, to avoid interfering with other app sections
        active: root.visible
        sourceComponent: BrowserShortcutActions {
            currentWebView: _internal.currentWebView
            onActivateAddressBar: browserToolbarLoader.activateAddressBar()
            onHideFindBar: findBar.visible = false
            onFindNextRequested: findBar.findNext()
            onFindPreviousRequested: findBar.findPrevious()
        }

        StatusBubble {
            id: statusBubble
            z: 54
            anchors.left: parent.left
            anchors.bottom: parent.bottom
        }

        Connections {
            target: _internal.currentWebView
            function onLinkHovered(hoveredUrl) {
                statusBubble.show(hoveredUrl)
            }
        }
    }

    Component {
        id: downloadViewComponent
        DownloadView {
            downloadsModel: root.downloadsStore.downloadModel
            downloadsMenu: downloadMenuInst
            onOpenDownloadClicked: function(downloadComplete, index) {
                downloadsContext.openDownloadFromList(downloadComplete, index)
            }
        }
    }

    Component {
        id: emptyPageComponent
        EmptyWebPage {
            bookmarksModel: root.bookmarksStore.bookmarksModel
            favMenu: favoriteMenu
            addFavModal: addFavoriteModal
            determineRealURLFn: function(url) {
                return root.browserRootStore.determineRealURL(url)
            }
            onSetCurrentWebUrl: (url) => webViewContext.setCurrentWebUrl(url)
            Component.onCompleted: {
                // Add fav button at the end of the grid
                var index = root.bookmarksStore.getBookmarkIndexByUrl(Constants.newBookmark)
                if (index !== -1) { root.bookmarksStore.deleteBookmark(Constants.newBookmark) }
                root.bookmarksStore.addBookmark(Constants.newBookmark, qsTr("Add Favourite"))
            }
        }
    }

    Component  {
        id: browserWalletMenu
        BrowserWalletMenu {
            parent: browserToolbarLoader
            x: browserToolbarLoader.width - width - Theme.halfPadding
            y: browserToolbarLoader.height + 4

            incognitoMode: _internal.currentTabIncognito
            accounts: root.browserWalletStore.accounts
            currentAccount: root.browserWalletStore.dappBrowserAccount
            activityStore: root.browserActivityStore
            currencyStore: root.currencyStore
            networksStore: root.networksStore

            onSendTriggered: (address) => root.sendToRecipientRequested(address)
            onAccountChanged: (newAddress) => connectorBridge.connectorManager.changeAccount(newAddress)
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

        incognitoMode: _internal.currentTabIncognito
        zoomFactor: _internal.currentWebView ? _internal.currentWebView.zoomFactor : 1
        onAddNewTab: _internal.addNewTab()
        onAddNewDownloadTab: _internal.addNewDownloadTab()
        onGoIncognito: (checked) => webViewContext.setIncognitoCurrent(checked)
        onZoomIn: webViewContext.changeZoomCurrent(0.1)
        onZoomOut: webViewContext.changeZoomCurrent(-0.1)
        onResetZoomFactor: webViewContext.resetZoomCurrent()
        onLaunchFindBar: {
            if (!findBar.visible) {
                findBar.visible = true;
                findBar.forceActiveFocus()
            }
        }
        onToggleCompatibilityMode: function(checked) {
            for (let i = 0; i < tabs.count; ++i){
                webViewContext.getWebView(i).stop() // Stop all loading tabs
            }

            localAccountSensitiveSettings.compatibilityMode = checked;

            for (let i = 0; i < tabs.count; ++i){
                webViewContext.getWebView(i).reload() // Reload them with new user agent
            }
        }
        onLaunchBrowserSettings: {
            Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.browserSettings);
        }

    }

    Component {
        id: addFavoriteModal
        AddFavoriteModal {
            parent: browserToolbarLoader
            x: Theme.halfPadding
            y: browserToolbarLoader.height + 4
            incognitoMode: _internal.currentTabIncognito
            bookmarksStore: root.bookmarksStore
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
            certErrors.shift().ignoreCertificateError();
            presentError();
        }
        onRejected: reject()

        function reject(){
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

    DownloadMenu {
        id: downloadMenuInst
        downloadsStore: root.downloadsStore
    }

    FavoriteMenu {
        id: favoriteMenu
        bookmarksStore: root.bookmarksStore
        onOpenInNewTab: (url) => root.openUrlInNewTab(url)
        onEditFavoriteTriggered: {
            favoritesContext.openAddFavoritePopup(true, favoriteMenu.currentFavorite)
        }
    }

    StatusMenu {
        id: historyMenu

        parent: browserToolbarLoader
        x: browserToolbarLoader.x + Theme.halfPadding
        y: browserToolbarLoader.height + 4

        Instantiator {
            model: _internal.currentWebView && _internal.currentWebView.history.items
            StatusMenuItem {
                text: model.title
                icon.source: model.icon
                onTriggered: _internal.currentWebView.goBackOrForward(model.offset)
                checkable: !enabled
                checked: !enabled
                enabled: model.offset
            }
            onObjectAdded: function(index, object) {
                historyMenu.insertItem(index, object)
            }
            onObjectRemoved: function(index, object) {
                historyMenu.removeItem(object)
            }
        }

    }

    Component {
        id: favoritesBar
        FavoritesBar {
            currentTabIncognito: _internal.currentTabIncognito
            bookmarkModel: root.bookmarksStore.bookmarksModel
            favoritesMenu: favoriteMenu
            onSetAsCurrentWebUrl: (url) => webViewContext.setCurrentWebUrl(url)
            onOpenInNewTab: (url) => root.openUrlInNewTab(url)
            onAddFavModalRequested: {
                favoritesContext.openAddFavoritePopup(false)
            }
        }
    }

    ConnectorBridge {
        id: connectorBridge

        userUID: root.userUID
        featureEnabled: root.dappsEnabled
        connectorController: root.dappsEnabled ? root.connectorController : null
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
        clientId: connectorBridge.clientId
        clientIdFilter: connectorBridge.clientId
    }

    Component {
        id: downloadBar
        DownloadBar {
            downloadsModel: root.downloadsStore.downloadModel
            downloadsMenu: downloadMenuInst
            onOpenDownloadClicked: function (downloadComplete, index) {
                downloadsContext.openDownloadFromList(downloadComplete, index)
            }
            onAddNewDownloadTab: _internal.addNewDownloadTab()
            onClose: root.showFooter = Qt.binding(() => root.invertedLayout)
        }
    }

    Connections {
        target: typeof browserSection !== "undefined" ? browserSection : null
        function onOpenUrl(url: string) {
            root.openUrlInNewTab(url);
        }
    }
}

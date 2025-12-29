import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

import QtModelsToolkit

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Layout
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared.controls
import shared
import shared.status
import shared.popups.send
import shared.stores.send
import shared.stores as SharedStores

import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Wallet.services.dapps

import "provider/qml"
import "popups"
import "controls"
import "views"
import "panels"

// Code based on https://code.qt.io/cgit/qt/qtwebengine.git/tree/examples/webengine/quicknanobrowser/BrowserWindow.qml?h=5.15
// Licensed under BSD

StatusSectionLayout {
    id: root

    required property string userUID
    required property bool thirdpartyServicesEnabled

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

    readonly property string userAgent: connectorBridge.httpUserAgent

    signal sendToRecipientRequested(string address)

    function openUrlInNewTab(url) {
        var tab = _internal.addNewTab()
        tab.url = _internal.determineRealURL(url)
    }

    function reloadCurrentTab() {
        _internal.currentWebView?.reload()
    }

    Component.onCompleted: {
        connectorBridge.defaultProfile.downloadRequested.connect(_internal.onDownloadRequested);
        connectorBridge.otrProfile.downloadRequested.connect(_internal.onDownloadRequested);
        var tab = webStackView.createEmptyTab(connectorBridge.defaultProfile, true);
        // For Devs: Uncomment the next line if you want to use the simpledapp on first load
        // tab.url = root.browserRootStore.determineRealURL("https://simpledapp.eth");
    }

    ConnectorBridge {
        id: connectorBridge

        userUID: root.userUID
        connectorController: root.connectorController
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
        connectorController: root.connectorController
        clientId: connectorBridge.clientId  // "status-desktop/dapp-browser"
    }

    QtObject {
        id: _internal

        property Item currentWebView: tabs.currentIndex < tabs.count ? webStackView.getCurrentWebView() : null
        readonly property bool currentTabIcognito: webStackView.getCurrentWebView()?.profile?.offTheRecord ?? false

        property Component browserDialogComponent: BrowserDialog {}

        property Component jsDialogComponent: JSDialogWindow {}

        property Component accessDialogComponent: BrowserConnectionModal {
            browserRootStore: root.browserRootStore
            browserWalletStore: root.browserWalletStore

            parent: browserWindow
            x: browserWindow.width - width - Theme.halfPadding
            y: browserWindow.y + browserHeader.height + Theme.halfPadding
        }

        property Component sendTransactionModalComponent: SendModal {
            anchors.centerIn: parent
            preSelectedHoldingID: "ETH"
            preSelectedHoldingType: Constants.TokenType.ERC20
            store: root.transactionStore
        }

        property Component signMessageModalComponent: SignMessageModal {
            browserRootStore: root.browserRootStore
            signingPhrase: root.browserWalletStore.signingPhrase
        }

        property StatusMessageDialog sendingError: StatusMessageDialog {
            title: qsTr("Error sending the transaction")
            icon: StatusMessageDialog.StandardIcon.Critical
            standardButtons: Dialog.Ok
        }

        property StatusMessageDialog signingError: StatusMessageDialog {
            title: qsTr("Error signing message")
            icon: StatusMessageDialog.StandardIcon.Critical
            standardButtons: Dialog.Ok
        }

        function addNewDownloadTab() {
            webStackView.createDownloadTab(tabs.count !== 0 ? currentWebView.profile : connectorBridge.defaultProfile);
            tabs.currentIndex = tabs.count - 1;
        }

        function addNewTab() {
            var tab = webStackView.createEmptyTab(tabs.count !== 0 ? currentWebView.profile : connectorBridge.defaultProfile);
            browserHeader.addressBar.forceActiveFocus();
            browserHeader.addressBar.selectAll();

            return tab;
        }

        function onDownloadRequested(download) {
            download.accept();
            root.downloadsStore.addDownload(download)
            downloadBar.active = true

            // close the tab launched only for starting download
            var downloadView = download.view
            if (!downloadView)
                return

            // find tab for this view
            for (var i = 0; i < tabs.count; ++i) {
                var tab = webStackView.getWebView(i)
                // close the “download-only” tab
                if (tab === downloadView &&
                        !tab.htmlPageLoaded &&
                        tab.title === "") {
                    webStackView.removeView(i)
                    break
                }
            }
        }

        function determineRealURL(url) {
            return root.browserRootStore.determineRealURL(url)
        }

        onCurrentWebViewChanged: {
            findBar.reset();
            browserHeader.addressBar.text = root.browserRootStore.obtainAddress(currentWebView.url)
        }
    }

    backgroundColor: Theme.palette.statusAppNavBar.backgroundColor

    headerContent: ColumnLayout {
        spacing: 0

        BrowserTabView {
            id: tabs

            Layout.fillWidth: true
            Layout.preferredHeight: 44

            currentTabIcognito: _internal.currentTabIcognito
            tabComponent: webEngineView
            currentWebEngineProfile: _internal.currentWebView.profile
            thirdpartyServicesEnabled: root.thirdpartyServicesEnabled
            determineRealURL: function(url) {
                return _internal.determineRealURL(url)
            }
            onOpenNewTabTriggered: _internal.addNewTab()
            fnGetWebView: (index) => {
                              return webStackView.getWebView(index)
                          }
            onRemoveView: (index) => {
                              webStackView.removeView(index)
                          }
        }

        BrowserHeader {
            id: browserHeader

            Layout.preferredWidth: parent.width

            favoriteComponent: favoritesBar
            favoritesVisible: localAccountSensitiveSettings.shouldShowFavoritesBar &&
                              root.bookmarksStore.bookmarksModel.ModelCount.count > 0
            currentTabIncognito: _internal.currentWebView?.profile.offTheRecord ?? false
            currentFavorite: _internal.currentWebView ? root.bookmarksStore.getCurrentFavorite(_internal.currentWebView.url) : null
            dappBrowserAccName: root.browserWalletStore.dappBrowserAccount.name
            dappBrowserAccIcon: Utils.getColorForId(Theme.palette, root.browserWalletStore.dappBrowserAccount.colorId)
            settingMenu: settingsMenu
            currentUrl: !!_internal.currentWebView ? _internal.currentWebView.url : ""
            isLoading: (!!_internal.currentWebView && _internal.currentWebView.loading)
            canGoBack: (!!_internal.currentWebView && _internal.currentWebView.canGoBack)
            canGoForward: (!!_internal.currentWebView && _internal.currentWebView.canGoForward)
            browserDappsModel: browserDappsProvider.model
            browserDappsCount: browserDappsProvider.model ? browserDappsProvider.model.count : 0
            onOpenHistoryPopup: () => historyMenu.open()
            onGoBack: _internal.currentWebView.goBack()
            onGoForward: _internal.currentWebView.goForward()
            onReload: _internal.currentWebView.reload()
            onStopLoading: _internal.currentWebView.stop()
            onOpenDappUrl: function(url) {
                if (_internal.currentWebView) {
                    _internal.currentWebView.url = _internal.determineRealURL(url)
                }
            }
            onDisconnectDapp: function(dappUrl) {
                connectorBridge.disconnect(dappUrl)
            }
            onAddNewFavoriteClicked: function() {
                Global.openPopup(addFavoriteModal,
                                 {
                                     modifiyModal: !!browserHeader.currentFavorite,
                                     toolbarMode: true,
                                     ogUrl: !!browserHeader.currentFavorite ? browserHeader.currentFavorite.url : _internal.currentWebView.url,
                                     ogName: !!browserHeader.currentFavorite ? browserHeader.currentFavorite.name : _internal.currentWebView.title
                                 })
            }
            onLaunchInBrowser: function(url) {
                if (localAccountSensitiveSettings.useBrowserEthereumExplorer !== Constants.browserEthereumExplorerNone && url.startsWith("0x")) {
                    _internal.currentWebView.url = root.browserRootStore.get0xFormedUrl(localAccountSensitiveSettings.useBrowserEthereumExplorer, url)
                    return
                }
                if (localAccountSensitiveSettings.selectedBrowserSearchEngineId !== SearchEnginesConfig.browserSearchEngineNone && !Utils.isURL(url) && !Utils.isURLWithOptionalProtocol(url)) {
                    _internal.currentWebView.url = root.browserRootStore.getFormedUrl(localAccountSensitiveSettings.selectedBrowserSearchEngineId, url)
                    return
                } else if (Utils.isURLWithOptionalProtocol(url)) {
                    url = "https://" + url
                }
                _internal.currentWebView.url = _internal.determineRealURL(url);
            }
            onOpenWalletMenu: {
                // Initialize activity filters before opening popup
                const activeChainIds = SQUtils.ModelUtils.modelToFlatArray(
                                         root.networksStore.activeNetworks, "chainId")
                if (activeChainIds.length > 0) {
                    root.browserActivityStore.activityController.setFilterChainsJson(
                                JSON.stringify(activeChainIds), true)
                }
                const currentAddress = root.browserWalletStore.dappBrowserAccount.address
                root.browserActivityStore.activityController.setFilterAddressesJson(
                            JSON.stringify([currentAddress]))

                Global.openPopup(browserWalletMenu)
            }
        }

        // TODO: integrate into the toolbar as per new design https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=3412-33124&m=dev
        FindBar {
            id: findBar
            visible: false

            Layout.preferredWidth: 300
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignRight
            z: 60

            onFindNext: {
                if (text)
                    _internal.currentWebView && _internal.currentWebView.findText(text);
                else if (!visible)
                    visible = true;
            }
            onFindPrevious: {
                if (text)
                    _internal.currentWebView && _internal.currentWebView.findText(text, WebEngineView.FindBackward);
                else if (!visible)
                    visible = true;
            }
        }
    }

    centerPanel: ColumnLayout {
        id: browserWindow

        StackLayout {
            id: webStackView
            currentIndex: tabs.currentIndex

            Layout.fillHeight: true
            Layout.fillWidth: true

            function createEmptyTab(profile, createAsStartPage = false, focusOnNewTab = true, url = undefined) {
                createAsStartPage = createAsStartPage || webStackView.count === 1
                let container = (createAsStartPage || !!url) ? webEngineView: emptyPage
                var webview = container.createObject(webStackView, {profile})
                tabs.createEmptyTab(createAsStartPage, focusOnNewTab, url, webview)
                return webview;
            }

            function createDownloadTab(profile) {
                var webview = downloadView.createObject(webStackView, {profile})
                tabs.createDownloadTab()
            }

            function getWebView(index) { // -> WebEngineView
                return webStackView.children[index]
            }

            function removeView(index) {
                if (tabs.count <= 1) {
                    createEmptyTab(_internal.currentWebView.profile, true)
                }
                tabs.removeTab(index)
                var view = getWebView(index)
                view.stop()
                view.parent = null // reparent to null first to prevent a crash
                view.destroy()
            }

            function getCurrentWebView() { // -> WebEngineView
                return getWebView(tabs.currentIndex)
            }
        }

        WebEngineView {
            id: devToolsView

            Layout.preferredHeight: visible ? 400 : 0
            Layout.fillWidth: true

            visible: localAccountSensitiveSettings.devToolsEnabled
            inspectedView: visible && tabs.currentIndex < tabs.count ? webStackView.getCurrentWebView() : null
            settings.forceDarkMode: Application.styleHints.colorScheme === Qt.ColorScheme.Dark
            onNewWindowRequested: function(request) {
                var tab = webStackView.createEmptyTab(_internal.currentWebView.profile);
                request.openIn(tab);
            }
            onWindowCloseRequested: localAccountSensitiveSettings.devToolsEnabled = false
            z: 100
        }

        // Non UI component
        Loader {
            // Only load the shortcuts when the browser is visible, to avoid interfering with other app sections
            active: root.visible
            sourceComponent: BrowserShortcutActions {
                currentWebView: _internal.currentWebView
                findBarComponent: findBar
                browserHeaderComponent: browserHeader
            }
        }
    }

    footer: Loader {
        id: downloadBar
        active: false
        height: active ? implicitHeight: 0
        sourceComponent: DownloadBar {
            downloadsModel: root.downloadsStore.downloadModel
            downloadsMenu: downloadMenuInst
            onOpenDownloadClicked: function (downloadComplete, index) {
                if (downloadComplete) {
                    return root.downloadsStore.openFile(index)
                }
                root.downloadsStore.openDirectory(index)
            }
            onAddNewDownloadTab: _internal.addNewDownloadTab()
            onClose: downloadBar.active = false
        }
    }

    Component  {
        id: browserWalletMenu
        BrowserWalletMenu {
            parent: browserHeader
            x: browserHeader.width - width - Theme.halfPadding
            y: browserHeader.height + 4

            incognitoMode: _internal.currentWebView && _internal.currentWebView.profile === connectorBridge.otrProfile
            accounts: root.browserWalletStore.accounts
            currentAccount: root.browserWalletStore.dappBrowserAccount
            activityStore: root.browserActivityStore
            currencyStore: root.currencyStore
            networksStore: root.networksStore

            onSendTriggered: (address) => root.sendToRecipientRequested(address)
            onAccountChanged: (newAddress) => connectorBridge.connectorManager.changeAccount(newAddress)
            onReload: {
                for (let i = 0; i < tabs.count; ++i){
                    webStackView.getWebView(i).reload();
                }
            }

            onAccountSwitchRequested: (address) => {
                                          root.browserWalletStore.switchAccountByAddress(address)
                                      }
            onFilterAddressesChangeRequested: (addressesJson) => {
                                                  root.browserActivityStore.activityController.setFilterAddressesJson(addressesJson)
                                              }

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

        parent: browserHeader
        x: parent.width - width - Theme.halfPadding
        y: browserHeader.height + 4

        incognitoMode: _internal.currentWebView && _internal.currentWebView.profile === connectorBridge.otrProfile
        zoomFactor: _internal.currentWebView ? _internal.currentWebView.zoomFactor : 1
        onAddNewTab: _internal.addNewTab()
        onAddNewDownloadTab: _internal.addNewDownloadTab()
        onGoIncognito: function (checked) {
            if (_internal.currentWebView) {
                _internal.currentWebView.profile = checked ? connectorBridge.otrProfile : connectorBridge.defaultProfile;
            }
        }
        onZoomIn: {
            const newZoom = _internal.currentWebView.zoomFactor + 0.1
            _internal.currentWebView.changeZoomFactor(newZoom)
        }
        onZoomOut: {
            const newZoom = _internal.currentWebView.zoomFactor - 0.1
            _internal.currentWebView.changeZoomFactor(newZoom)
        }
        onResetZoomFactor: _internal.currentWebView.changeZoomFactor(1.0)
        onLaunchFindBar: {
            if (!findBar.visible) {
                findBar.visible = true;
                findBar.forceActiveFocus()
            }
        }
        onToggleCompatibilityMode: function(checked) {
            for (let i = 0; i < tabs.count; ++i){
                webStackView.getWebView(i).stop() // Stop all loading tabs
            }

            localAccountSensitiveSettings.compatibilityMode = checked;

            for (let i = 0; i < tabs.count; ++i){
                webStackView.getWebView(i).reload() // Reload them with new user agent
            }
        }
        onLaunchBrowserSettings: {
            Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.browserSettings);
        }
    }

    Component {
        id: addFavoriteModal
        AddFavoriteModal {
            parent: browserHeader
            x: browserHeader.width - width - Theme.halfPadding
            y: browserHeader.height + 4
            incognitoMode: _internal.currentWebView && _internal.currentWebView.profile === connectorBridge.otrProfile
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
            Global.openPopup(addFavoriteModal, {
                                 modifiyModal: true,
                                 ogUrl: favoriteMenu.currentFavorite ? favoriteMenu.currentFavorite.url : _internal.currentWebView.url,
                                 ogName: favoriteMenu.currentFavorite ? favoriteMenu.currentFavorite.name : _internal.currentWebView.title})
        }
    }

    StatusMenu {
        id: historyMenu

        parent: browserHeader
        x: browserHeader.x + Theme.halfPadding
        y: browserHeader.height + 4

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
            bookmarkModel: root.bookmarksStore.bookmarksModel
            favoritesMenu: favoriteMenu
            onSetAsCurrentWebUrl: (url) => _internal.currentWebView.url = _internal.determineRealURL(url)
            onOpenInNewTab: (url) => root.openUrlInNewTab(url)
            onAddFavModalRequested: {
                Global.openPopup(addFavoriteModal, {toolbarMode: true,
                                     ogUrl: browserHeader.currentFavorite ? browserHeader.currentFavorite.url : _internal.currentWebView.url,
                                     ogName: browserHeader.currentFavorite ? browserHeader.currentFavorite.name : _internal.currentWebView.title})
            }
        }
    }

    Component {
        id: webEngineView
        BrowserWebEngineView {
            currentWebView: _internal.currentWebView
            webChannel: connectorBridge.channel
            enableJsLogs: root.isDebugEnabled

            onLinkHovered: function(hoveredUrl) {
                if (hoveredUrl.toString() === "") {
                    hideStatusText.start();
                } else {
                    statusText.text = hoveredUrl;
                    statusBubble.visible = true;
                    hideStatusText.stop();
                }
            }
            onWindowCloseRequested: tabs.removeView(StackLayout.index)
            onNewWindowRequested: function(request) {
                if (!request.userInitiated) {
                    console.warn("Warning: Blocked a popup window.");
                } else if (request.destination === WebEngineNewWindowRequest.InNewTab) {
                    var tab = webStackView.createEmptyTab(_internal.currentWebView.profile, false, true, request.requestedUrl);
                    tab.acceptAsNewWindow(request);
                } else if (request.destination === WebEngineNewWindowRequest.InNewBackgroundTab) {
                    var backgroundTab = webStackView.createEmptyTab(_internal.currentWebView.profile, false, false, request.requestedUrl);
                    backgroundTab.acceptAsNewWindow(request);
                    // Disabling popups temporarily since we need to set that webengineview settings / channel and other properties
                    /*} else if (request.destination === WebEngineNewWindowRequest.InNewDialog) {
                    var dialog = browserDialogComponent.createObject();
                    dialog.currentWebView.profile = currentWebView.profile;
                    dialog.currentWebView.webChannel = channel;
                    request.openIn(dialog.currentWebView);*/
                } else {
                    // Instead of opening a new window, we open a new tab
                    // TODO: remove "open in new window" from context menu
                    var tab = webStackView.createEmptyTab(_internal.currentWebView.profile, false, true, request.requestedUrl);
                    tab.acceptAsNewWindow(request);
                }
            }
            onCertificateError: function(error) {
                error.defer();
                sslDialog.enqueue(error);
            }
            onJavaScriptDialogRequested: function(request) {
                request.accepted = true;
                var dialog = _internal.jsDialogComponent.createObject(root, {"request": request});
                dialog.open();
            }

            onShowFindBar: function(numberOfMatches, activeMatch) {
                if (!findBar.visible)
                    findBar.visible = true

                findBar.numberOfMatches = numberOfMatches;
                findBar.activeMatch = activeMatch;
            }

            onResetFindBar: function() {
                findBar.reset()
            }

            Rectangle {
                id: statusBubble
                color: Theme.palette.baseColor2
                visible: false
                z: 54

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Math.min(statusText.implicitWidth, parent.width)
                height: statusText.implicitHeight

                StatusBaseText {
                    id: statusText
                    anchors.fill: parent
                    verticalAlignment: Qt.AlignVCenter
                    elide: Qt.ElideMiddle
                    padding: 4

                    Timer {
                        id: hideStatusText
                        interval: 750
                        onTriggered: {
                            statusText.text = "";
                            statusBubble.visible = false;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: downloadView
        DownloadView {
            downloadsModel: root.downloadsStore.downloadModel
            downloadsMenu: downloadMenuInst
            onOpenDownloadClicked: function(downloadComplete, index) {
                if (downloadComplete) {
                    return root.downloadsStore.openFile(index)
                }
                root.downloadsStore.openDirectory(index)
            }
        }
    }

    Component {
        id: emptyPage
        EmptyWebPage {
            bookmarksModel: root.bookmarksStore.bookmarksModel
            favMenu: favoriteMenu
            addFavModal: addFavoriteModal
            determineRealURLFn: function(url) {
                return _internal.determineRealURL(url)
            }
            onSetCurrentWebUrl: (url) => {
                                    _internal.currentWebView.url = url
                                }
            Component.onCompleted: {
                // Add fav button at the end of the grid
                var index = root.bookmarksStore.getBookmarkIndexByUrl(Constants.newBookmark)
                if (index !== -1) { root.bookmarksStore.deleteBookmark(Constants.newBookmark) }
                root.bookmarksStore.addBookmark(Constants.newBookmark, qsTr("Add Favourite"))
            }
        }
    }

    Connections {
        target: _internal.currentWebView
        function onUrlChanged() {
            browserHeader.addressBar.text = root.browserRootStore.obtainAddress(_internal.currentWebView.url)
            
            // Update ConnectorBridge with current dApp metadata
            if (_internal.currentWebView && _internal.currentWebView.url) {
                connectorBridge.connectorManager.updateDAppUrl(
                            _internal.currentWebView.url,
                            _internal.currentWebView.title,
                            _internal.currentWebView.icon
                            )
            }
        }
    }

    Connections {
        target: root.bookmarksStore.bookmarksModel
        function onModelChanged() {
            browserHeader.currentFavorite = Qt.binding(function () {return root.bookmarksStore.getCurrentFavorite(_internal.currentWebView.url)})
        }
    }

    Connections {
        target: typeof browserSection !== "undefined" ? browserSection : null
        function onOpenUrl(url: string) {
            root.openUrlInNewTab(url);
        }
    }
}

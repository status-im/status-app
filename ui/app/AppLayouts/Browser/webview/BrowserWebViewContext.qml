import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Browser.adapters
import AppLayouts.Browser.provider.qml

import "../provider/qml/Utils.js" as BrowserProviderUtils

QtObject {
    id: root

    required property bool thirdpartyServicesEnabled
    required property bool isDebugEnabled
    required property bool isMobile
    required property bool hasPopups

    required property var browserSettings
    required property var connectorController
    required property bool dappsEnabled

    required property Item hostStackLayout
    required property var tabsModel
    required property ProfileParams defaultProfileParams
    required property ProfileParams otrProfileParams

    required property var bookmarksStore
    required property var downloadsStore

    readonly property var profileManager: _profileManagerLoader.item

    readonly property Loader _profileManagerLoader: Loader {
        active: !root.isMobile
        source: "../adapters/ProfileManager.qml"
    }

    required property var determineRealURLFn
    required property var downloadRequestHandler
    required property var sslErrorHandler
    required property var jsDialogHandler
    required property var findTextFinishedHandler
    required property var savedSessionContext

    enum ContentMode {
        WebContent = 0,
        DownloadContent,
        EmptyContent
    }

    readonly property Item currentWebView: tabsModel.currentIndex < tabsModel.count ? (getCurrentWebView() ?? null) : null
    readonly property int currentContentMode: {
        if (!currentWebView)
            return BrowserWebViewContext.ContentMode.EmptyContent
        if (currentWebView.isDownloadView)
            return BrowserWebViewContext.ContentMode.DownloadContent
        if (!currentWebView.url?.toString())
            return BrowserWebViewContext.ContentMode.EmptyContent
        return BrowserWebViewContext.ContentMode.WebContent
    }

    readonly property string currentClientId: currentWebView?.bridge?.clientId
                                              ?? ConnectorConstants.clientIdFor(currentWebView ? currentWebView.offTheRecord : false)

    readonly property Connections _currentIndexConnections: Connections {
        target: tabsModel
        function onCurrentIndexChanged() {
            root.ensureCurrentWebViewLoaded()
        }
    }

    function createEmptyTab(profileParams, createAsStartPage = false, focusOnNewTab = true, url = undefined, initialTitle = undefined, initialIcon = undefined, initialUid = undefined) {
        focusOnNewTab = focusOnNewTab && !createAsStartPage

        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams,
            isDownloadView: false
        })
        if (!webview) {
            console.error("[Browser] Failed to create webview")
            return null
        }

        webview.uid = (initialUid || "").trim() || SQUtils.Utils.uuid()

        savedSessionContext.seedWebView(webview, { title: initialTitle, icon: initialIcon })

        tabsModel.createEmptyTab(createAsStartPage, focusOnNewTab)

        if (createAsStartPage && thirdpartyServicesEnabled)
            webview.url = Constants.browserDefaultHomepage
        else if (url !== undefined)
            webview.url = url
        else if (!!browserSettings.browserHomepage)
            webview.url = determineRealURLFn(browserSettings.browserHomepage)

        if ((focusOnNewTab || createAsStartPage) && webview.url.toString() && typeof webview.ensureLoaded === "function")
            webview.ensureLoaded()

        return webview
    }

    function createDownloadTab(profileParams) {
        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams,
            isDownloadView: true
        })
        if (!webview) {
            console.error("[Browser] Failed to create download webview")
            return null
        }

        tabsModel.createDownloadTab()
        webview.uid = SQUtils.Utils.uuid()
        webview.ensureLoaded()
        return webview
    }

    function getCurrentWebView() { // -> WebEngineView/WebView
        return getWebView(tabsModel.currentIndex)
    }

    function getWebView(index) { // -> WebEngineView/WebView
        return hostStackLayout.children[index]
    }

    function ensureCurrentWebViewLoaded() {
        const w = getCurrentWebView()
        if (w && w.url && w.url.toString() && typeof w.ensureLoaded === "function")
            w.ensureLoaded()
    }

    function setCurrentWebUrl(url) {
        var target = currentWebView
        if (!target) {
            console.error("[Browser] currentWebView is null, cannot set URL")
            return
        }

        const newUrl = determineRealURLFn(url)
        Qt.callLater(function() {
            target.url = newUrl
            if (newUrl && newUrl.toString() && typeof target.ensureLoaded === "function")
                target.ensureLoaded()
        })
    }

    function disconnectDapp(dappUrl) {
        const origin = BrowserProviderUtils.normalizeOrigin(dappUrl)
        if (!origin || !connectorController)
            return false

        return connectorController.disconnect(origin, currentClientId)
    }

    function changeAccountForCurrentDapp(address) {
        currentWebView?.bridge?.connectorManager.changeAccount(address)
    }

    function goBackCurrent() {
        if (!currentWebView)
            return
        currentWebView.goBack()
    }

    function goForwardCurrent() {
        if (!currentWebView)
            return
        currentWebView.goForward()
    }

    function goBackOrForwardCurrent(offset) {
        if (!currentWebView)
            return
        currentWebView.goBackOrForward(offset)
    }

    function reloadCurrent() {
        if (!currentWebView)
            return
        if (typeof currentWebView.ensureLoaded === "function")
            currentWebView.ensureLoaded()
        currentWebView.reload()
    }

    function stopCurrent() {
        if (!currentWebView)
            return
        currentWebView.stop()
    }

    function findTextCurrent(text, backward = false) {
        if (!currentWebView)
            return

        if (backward) {
            currentWebView.findText(text, currentWebView.findBackward)
            return
        }

        currentWebView.findText(text)
    }

    function setIncognitoCurrent(checked) {
        if (!currentWebView)
            return
        const target = checked ? otrProfileParams : defaultProfileParams
        if (currentWebView.profileParams !== target)
            currentWebView.profileParams = target
    }

    function changeZoomCurrent(delta) {
        if (!currentWebView)
            return
        currentWebView.changeZoomFactor(currentWebView.zoomFactor + delta)
    }

    function resetZoomCurrent() {
        if (!currentWebView)
            return
        currentWebView.changeZoomFactor(1.0)
    }

    function removeView(index) {
        if (index < 0 || index >= tabsModel.count)
            return

        var view = getWebView(index)
        if (tabsModel.count <= 1) {
            var fallbackProfileParams = root.currentWebView ? currentWebView.profileParams : root.defaultProfileParams
            createEmptyTab(fallbackProfileParams, true)
        }
        tabsModel.removeTab(index)
        if (!view)
            return
        view.visible = false
        view.enabled = false
        view.focus = false
        view.detachView()
        view.parent = null
        view.destroy()
    }

    readonly property var webViewAdapterComponent: Component {
        LazyWebViewAdapter {
            id: lazyView

            // On mobile, only the active tab must be visible; native WKWebView
            // subviews share the same UIKit window and ignore QML z-order,
            // so StackLayout alone cannot hide inactive tabs reliably.
            visible: root.isMobile ? StackLayout.isCurrentItem : true
            enabled: visible
            // Freeze native webview while QML popup is shown
            freeze: root.isMobile && root.hasPopups

            readonly property ConnectorBridge bridge: ConnectorBridge {
                connectorController: root.dappsEnabled ? root.connectorController : null
                tabUrl: lazyView.url
                tabIncognito: lazyView.offTheRecord
                tabTitle: lazyView.title
                tabIconUrl: lazyView.icon
            }

            webChannel: bridge.channel

            bookmarksStore: root.bookmarksStore
            downloadsStore: root.downloadsStore
            profileManager: root.profileManager
            enableJsLogs: root.isDebugEnabled
            localAccountSensitiveSettings: root.browserSettings

            devToolsEnabled: root.browserSettings.devToolsEnabled
            onDevToolsToggled: enabled => root.browserSettings.devToolsEnabled = enabled

            onWindowCloseRequested: root.removeView(StackLayout.index)
            onNewWindowRequested: (makeCurrent, requestedUrl, callback) => {
                var profileParams = root.currentWebView ? root.currentWebView.profileParams : root.defaultProfileParams
                var tab = root.createEmptyTab(profileParams, false, makeCurrent, requestedUrl)
                callback(tab)
            }
            onDownloadRequested: (download) => root.downloadRequestHandler(download)
            onCertificateError: (error) => root.sslErrorHandler(error)
            onJavaScriptDialogRequested: (request) => root.jsDialogHandler(request)
            onFindTextFinished: (result) => root.findTextFinishedHandler(result)
        }
    }
}

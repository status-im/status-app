import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import AppLayouts.Browser.adapters

QtObject {
    id: root

    required property bool thirdpartyServicesEnabled
    required property bool isDebugEnabled
    required property bool isMobile
    required property bool hasPopups

    required property var browserSettings
    required property var webChannel

    required property Item hostStackLayout
    required property var tabsModel
    required property ProfileParams defaultProfileParams

    required property var bookmarksStore
    required property var downloadsStore

    required property var determineRealURLFn
    required property var downloadRequestHandler
    required property var sslErrorHandler
    required property var jsDialogHandler
    required property var findTextFinishedHandler

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

    readonly property Connections _currentIndexConnections: Connections {
        target: tabsModel
        function onCurrentIndexChanged() {
            root.ensureCurrentWebViewLoaded()
        }
    }

    function createEmptyTab(profileParams, createAsStartPage = false, focusOnNewTab = true, url = undefined, initialTitle = undefined, initialIcon = undefined) {
        focusOnNewTab = focusOnNewTab && !createAsStartPage

        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams,
            isDownloadView: false
        })

        tabsModel.createEmptyTab(createAsStartPage, focusOnNewTab, webview, initialTitle, initialIcon)

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
        tabsModel.createDownloadTab()
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
        currentWebView.profileParams.offTheRecord = checked
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
            // On mobile, only the active tab must be visible; native WKWebView
            // subviews share the same UIKit window and ignore QML z-order,
            // so StackLayout alone cannot hide inactive tabs reliably.
            visible: root.isMobile ? StackLayout.isCurrentItem : true
            enabled: visible
            // Freeze native webview while QML popup is shown
            freeze: root.isMobile && root.hasPopups

            bookmarksStore: root.bookmarksStore
            downloadsStore: root.downloadsStore
            webChannel: root.webChannel
            enableJsLogs: root.isDebugEnabled
            localAccountSensitiveSettings: root.browserSettings
            devToolsEnabled: root.browserSettings.devToolsEnabled

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

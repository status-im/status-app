import QtQuick
import QtQuick.Controls

import utils
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.adapters

Item {
    id: root
    visible: false

    required property bool thirdpartyServicesEnabled
    required property bool isDebugEnabled
    required property bool isMobile

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

    readonly property Item currentWebView: tabsModel.currentIndex < tabsModel.count ? getCurrentWebView() : null
    readonly property int currentContentMode: {
        if (!currentWebView)
            return BrowserWebViewContext.ContentMode.EmptyContent
        if (currentWebView.isDownloadView)
            return BrowserWebViewContext.ContentMode.DownloadContent
        if (!currentWebView.url?.toString())
            return BrowserWebViewContext.ContentMode.EmptyContent
        return BrowserWebViewContext.ContentMode.WebContent
    }

    function createEmptyTab(profileParams, createAsStartPage = false, focusOnNewTab = true, url = undefined) {
        focusOnNewTab = focusOnNewTab && !createAsStartPage

        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams,
            isDownloadView: false
        })

        tabsModel.createEmptyTab(createAsStartPage, focusOnNewTab, webview)

        if (createAsStartPage && thirdpartyServicesEnabled) {
            webview.url = Constants.browserDefaultHomepage
        } else if (url !== undefined) {
            webview.url = url
        } else if (!!browserSettings.browserHomepage) {
            webview.url = determineRealURLFn(browserSettings.browserHomepage)
        }

        return webview
    }

    function createDownloadTab(profileParams) {
        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams,
            isDownloadView: true
        })
        tabsModel.createDownloadTab()
        return webview
    }

    function getCurrentWebView() { // -> WebEngineView/WebView
        return getWebView(tabsModel.currentIndex)
    }

    function getWebView(index) { // -> WebEngineView/WebView
        return hostStackLayout.children[index]
    }

    function setCurrentWebUrl(url) {
        if (!currentWebView) {
            console.error("[Browser] currentWebView is null, cannot set URL")
            return
        }

        const newUrl = determineRealURLFn(url)
        Qt.callLater(function() {
            if (currentWebView)
                currentWebView.url = newUrl
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
        if (!currentWebView || !text)
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
            var fallbackProfileParams = currentWebView ? currentWebView.profileParams : defaultProfileParams
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

    Component {
        id: webViewAdapterComponent
        WebViewAdapter {
            visible: !SQUtils.Utils.hasPopups(Overlay.overlay.children) || !root.isMobile
            enabled: visible

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

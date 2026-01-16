import QtQuick
import QtWebEngine

import StatusQ.Core.Theme

import AppLayouts.Browser.views
import AppLayouts.Browser.provider.qml

AbstractWebView {
    id: root

    property bool enableJsLogs: false

    property var profile: ProfileManager.getProfile(root.profileParams)

    // Expose BrowserWebEngineView properties
    property alias url: webView.url
    readonly property alias title: webView.title
    readonly property alias loading: webView.loading
    readonly property alias canGoBack: webView.canGoBack
    readonly property alias canGoForward: webView.canGoForward
    readonly property alias loadProgress: webView.loadProgress
    readonly property alias zoomFactor: webView.zoomFactor
    readonly property alias history: webView.history
    readonly property alias icon: webView.icon
    readonly property alias htmlPageLoaded: webView.htmlPageLoaded

    // Capability flags for WebEngine
    readonly property bool supportsZoom: true
    readonly property bool supportsDevTools: true
    readonly property bool supportsFindInPage: true
    readonly property bool supportsIncognito: true
    readonly property bool supportsHistory: true

    // Override functions
    function loadUrl(newUrl) { webView.url = newUrl }
    function goBack() { webView.goBack() }
    function goForward() { webView.goForward() }
    function goBackOrForward(offset) { webView.goBackOrForward(offset) }
    function reload() { webView.reload() }
    function stop() { webView.stop() }
    function findText(text, flags) { webView.findText(text, flags) }
    function changeZoomFactor(factor) { webView.changeZoomFactor(factor) }
    function acceptAsNewWindow(request) { request.openIn(webView) }
    function triggerWebAction(action) {
        // Map AbstractWebView.WebAction to WebEngineView.WebAction
        switch (action) {
            case AbstractWebView.WebAction.NoWebAction:
                webView.triggerWebAction(WebEngineView.NoWebAction); break
            case AbstractWebView.WebAction.Back:
                webView.triggerWebAction(WebEngineView.Back); break
            case AbstractWebView.WebAction.Forward:
                webView.triggerWebAction(WebEngineView.Forward); break
            case AbstractWebView.WebAction.Stop:
                webView.triggerWebAction(WebEngineView.Stop); break
            case AbstractWebView.WebAction.Reload:
                webView.triggerWebAction(WebEngineView.Reload); break
            case AbstractWebView.WebAction.Cut:
                webView.triggerWebAction(WebEngineView.Cut); break
            case AbstractWebView.WebAction.Copy:
                webView.triggerWebAction(WebEngineView.Copy); break
            case AbstractWebView.WebAction.Paste:
                webView.triggerWebAction(WebEngineView.Paste); break
            case AbstractWebView.WebAction.Undo:
                webView.triggerWebAction(WebEngineView.Undo); break
            case AbstractWebView.WebAction.RequestClose:
                webView.triggerWebAction(WebEngineView.RequestClose); break
            case AbstractWebView.WebAction.Redo:
                webView.triggerWebAction(WebEngineView.Redo); break
            case AbstractWebView.WebAction.SelectAll:
                webView.triggerWebAction(WebEngineView.SelectAll); break
            case AbstractWebView.WebAction.PasteAndMatchStyle:
                webView.triggerWebAction(WebEngineView.PasteAndMatchStyle); break
            default:
                console.warn("WebEngineAdapter: Unknown web action:", action)
        }
    }

    BrowserWebEngineView {
        id: webView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.devToolsEnabled ? devToolsView.top : parent.bottom

        webChannel: root.webChannel
        profile: root.profile
        enableJsLogs: root.enableJsLogs

        onLinkHovered: (hoveredUrl) => root.linkHovered(hoveredUrl)
        onWindowCloseRequested: root.windowCloseRequested()
        onNewWindowRequested: (request) => {
            if (!request.userInitiated) {
                console.warn("Warning: Blocked a popup window.");
            } else {
                const makeCurrent = request.destination !== WebEngineNewWindowRequest.InNewBackgroundTab
                root.newWindowRequested(makeCurrent, request.requestedUrl, (tab) => tab.acceptAsNewWindow(request))
            }
        }
        onCertificateError: (error) => root.certificateError(error)
        onJavaScriptDialogRequested: (request) => root.javaScriptDialogRequested(request)
        onFindTextFinished: (result) => root.findTextFinished(result)
        onShowFindBar: (numberOfMatches, activeMatch) => root.findTextFinished({numberOfMatches, activeMatch})
    }

    WebEngineView {
        id: devToolsView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.devToolsEnabled ? root.devToolsHeight : 0
        visible: root.devToolsEnabled
        inspectedView: root.devToolsEnabled ? webView : null
        settings.forceDarkMode: Application.styleHints.colorScheme === Qt.ColorScheme.Dark

        onWindowCloseRequested: {
            root.devToolsEnabled = false
        }
    }

    Connections {
        target: root.profile
        function onDownloadRequested(download) {
            root.downloadRequested(download)
        }
    }

    Connections {
        // This connection is needed because changing profileParams.offTheRecord doesn't trigger the root.profile update
        target: root.profileParams
        function onOffTheRecordChanged() {
            root.profile = ProfileManager.getProfile(root.profileParams)
        }
    }
}

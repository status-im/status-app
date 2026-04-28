import QtQuick

// Thin AbstractWebView that wraps WebViewAdapter in a Loader so WebEngineView is not created for
// empty tabs. Activation is imperative and one-shot (loader.active flips true once, never back).
// BrowserWebViewContext calls ensureLoaded() when switching to or loading a tab. Proxied state
// defaults until the inner item exists. Capability flags are also proxied from loader.item so that
// the correct per-platform values are reported automatically (e.g. +mobile/WebViewAdapter reports
// supportsDevTools=false, supportsIncognito=false, dynamic hasNativeFindPanel); no separate
// +mobile/LazyWebViewAdapter.qml is needed.

AbstractWebView {
    id: root

    supportsZoom:       loader.item ? loader.item.supportsZoom       : false
    supportsDevTools:   loader.item ? loader.item.supportsDevTools   : false
    supportsFindInPage: loader.item ? loader.item.supportsFindInPage : false
    supportsIncognito:  loader.item ? loader.item.supportsIncognito  : false
    supportsHistory:    loader.item ? loader.item.supportsHistory    : false
    hasNativeFindPanel: loader.item ? loader.item.hasNativeFindPanel : false

    readonly property string title: loader.item ? loader.item.title : ""
    readonly property bool loading: loader.item ? loader.item.loading : false
    readonly property bool canGoBack: loader.item ? loader.item.canGoBack : false
    readonly property bool canGoForward: loader.item ? loader.item.canGoForward : false
    readonly property real loadProgress: loader.item ? loader.item.loadProgress : 0
    readonly property real zoomFactor: loader.item ? loader.item.zoomFactor : 1.0
    readonly property var history: loader.item ? loader.item.history : null
    readonly property url icon: loader.item ? loader.item.icon : ""
    readonly property bool htmlPageLoaded: loader.item ? loader.item.htmlPageLoaded : false
    readonly property var scrollPosition: loader.item ? loader.item.scrollPosition : Qt.point(0, 0)

    function ensureLoaded() {
        if (!loader.active)
            loader.active = true
    }

    function loadUrl(u) {
        root.url = u
        if (u && u.toString())
            ensureLoaded()
    }
    function goBack()             { if (loader.item) loader.item.goBack() }
    function goForward()          { if (loader.item) loader.item.goForward() }
    function goBackOrForward(o)   { if (loader.item) loader.item.goBackOrForward(o) }
    function reload()             { if (loader.item) loader.item.reload() }
    function stop()               { if (loader.item) loader.item.stop() }
    function findText(text, flags){ if (loader.item) loader.item.findText(text, flags) }
    function showFindPanel()      { if (loader.item) loader.item.showFindPanel() }
    function hideFindPanel()      { if (loader.item) loader.item.hideFindPanel() }
    function changeZoomFactor(f)  { if (loader.item) loader.item.changeZoomFactor(f) }
    function acceptAsNewWindow(req){ if (loader.item) loader.item.acceptAsNewWindow(req) }
    function triggerWebAction(a)  { if (loader.item) loader.item.triggerWebAction(a) }

    function detachView() {
        if (loader.item)
            loader.item.detachView()
    }

    onUrlChanged: {
        if (loader.item && loader.item.url !== url)
            loader.item.url = url
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: false
        sourceComponent: WebViewAdapter {
            profileParams:               root.profileParams
            bookmarksStore:              root.bookmarksStore
            downloadsStore:              root.downloadsStore
            webChannel:                  root.webChannel
            devToolsEnabled:             root.devToolsEnabled
            enableJsLogs:                root.enableJsLogs
            localAccountSensitiveSettings: root.localAccountSensitiveSettings
            isDownloadView:              root.isDownloadView
            freeze:                      root.freeze

            Component.onCompleted: if (root.url.toString()) url = root.url

            onUrlChanged: { if (root.url !== url) root.url = url }
        }
    }

    Connections {
        target: loader.item
        function onLinkHovered(hoveredUrl)             { root.linkHovered(hoveredUrl) }
        function onWindowCloseRequested()              { root.windowCloseRequested() }
        function onDownloadRequested(download)         { root.downloadRequested(download) }
        function onNewWindowRequested(makeCurrent, requestedUrl, callback) {
            root.newWindowRequested(makeCurrent, requestedUrl, callback)
        }
        function onCertificateError(error)             { root.certificateError(error) }
        function onJavaScriptDialogRequested(request)  { root.javaScriptDialogRequested(request) }
        function onFindTextFinished(result)            { root.findTextFinished(result) }
    }
}

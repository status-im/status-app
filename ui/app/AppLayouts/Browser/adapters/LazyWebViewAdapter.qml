import QtQuick

import StatusQ.Core.Utils as SQUtils

// Thin AbstractWebView that loads a per-platform WebViewAdapter on demand via
// a Loader, so the heavy WebEngineView (or the native MobileWebViewBackend)
// is not constructed for empty tabs. Activation is imperative and one-shot:
// BrowserWebViewContext calls ensureLoaded() when switching to or loading a
// tab. Capability flags and proxied state default while loader.item is null
// and pick up the per-platform values once loaded — so reported flags such
// as supportsDevTools/supportsIncognito/hasNativeFindPanel match the
// underlying adapter automatically.

AbstractWebView {
    id: root

    // Desktop-only: WebEngineProfile owner injected from BrowserWebViewContext.
    // Null on mobile (MobileWebViewAdapter doesn't need it).
    // WARN: needs to remain a var to avoid mixing platform-specific types
    property var profileManager: null

    supportsZoom:           loader.item ? loader.item.supportsZoom           : false
    supportsDevTools:       loader.item ? loader.item.supportsDevTools       : false
    supportsFindInPage:     loader.item ? loader.item.supportsFindInPage     : false
    supportsIncognito:      loader.item ? loader.item.supportsIncognito      : false
    supportsHistory:        loader.item ? loader.item.supportsHistory        : false
    hasNativeFindPanel:     loader.item ? loader.item.hasNativeFindPanel     : false
    clearSiteDataSupported: loader.item ? loader.item.clearSiteDataSupported : false
    clearing:               loader.item ? loader.item.clearing               : false

    property string title: ""
    property url icon: ""
    property bool htmlPageLoaded: false
    // A committed page load ends "pristine" for good — from here the Tab shows a
    // page of its own, so no Download may close it.
    onHtmlPageLoadedChanged: if (htmlPageLoaded) root.pristinePopup = false
    readonly property bool loading: loader.item ? loader.item.loading : false
    readonly property bool canGoBack: loader.item ? loader.item.canGoBack : false
    readonly property bool canGoForward: loader.item ? loader.item.canGoForward : false
    readonly property real loadProgress: loader.item ? loader.item.loadProgress : 0
    readonly property real zoomFactor: loader.item ? loader.item.zoomFactor : 1.0
    readonly property var history: loader.item ? loader.item.history : null
    readonly property var scrollPosition: loader.item ? loader.item.scrollPosition : Qt.point(0, 0)

    function syncFromAdapterItem() {
        const item = loader.item
        if (!item)
            return

        const nextTitle = item.title || ""
        if (nextTitle && root.title !== nextTitle)
            root.title = nextTitle

        const nextIcon = item.icon || ""
        if (nextIcon && String(root.icon) !== String(nextIcon))
            root.icon = nextIcon

        const nextLoaded = !!item.htmlPageLoaded
        if (root.htmlPageLoaded !== nextLoaded)
            root.htmlPageLoaded = nextLoaded
    }

    function ensureLoaded() {
        if (loader.status !== Loader.Null)
            return
        const props = {
            profileParams:                 Qt.binding(() => root.profileParams),
            uid:                           Qt.binding(() => root.uid),
            bookmarksStore:                Qt.binding(() => root.bookmarksStore),
            webChannel:                    Qt.binding(() => root.webChannel),
            enableJsLogs:                  Qt.binding(() => root.enableJsLogs),
            localAccountSensitiveSettings: Qt.binding(() => root.localAccountSensitiveSettings),
            devToolsEnabled:               Qt.binding(() => root.devToolsEnabled),
            freeze:                        Qt.binding(() => root.freeze),
        }
        if (!SQUtils.Utils.isMobile)
            props.profileManager = Qt.binding(() => root.profileManager)
        loader.setSource(loader.adapterPath, props)
    }

    function loadUrl(u) {
        root.url = u
        if (u && u.toString())
            ensureLoaded()
    }
    /// Local-file load with a directory read grant; url syncs back via Connections.
    function loadFileUrl(fileUrl, readAccessUrl) {
        ensureLoaded()
        if (loader.item && loader.item.loadFileUrl)
            loader.item.loadFileUrl(fileUrl, readAccessUrl || "")
        else
            console.warn("LazyWebViewAdapter: loadFileUrl unavailable")
    }
    function goBack()             { if (loader.item) loader.item.goBack() }
    function goForward()          { if (loader.item) loader.item.goForward() }
    function goBackOrForward(o)   { if (loader.item) loader.item.goBackOrForward(o) }
    function reload() {
        ensureLoaded()
        if (loader.item)
            loader.item.reload()
    }
    function stop()               { if (loader.item) loader.item.stop() }
    function forceReload() {
        ensureLoaded()
        if (loader.item)
            loader.item.forceReload()
    }
    function clearSiteData() {
        ensureLoaded()
        if (loader.item)
            loader.item.clearSiteData()
    }
    function clearBrowsingData() {
        ensureLoaded()
        if (loader.item)
            loader.item.clearBrowsingData()
    }
    function runJavaScript(script, callback) {
        ensureLoaded()
        if (loader.item)
            loader.item.runJavaScript(script, callback)
    }
    function findText(text, flags){ if (loader.item) loader.item.findText(text, flags) }
    function showFindPanel()      { if (loader.item) loader.item.showFindPanel() }
    function hideFindPanel()      { if (loader.item) loader.item.hideFindPanel() }
    function changeZoomFactor(f)  { if (loader.item) loader.item.changeZoomFactor(f) }
    function acceptAsNewWindow(req){ if (loader.item) loader.item.acceptAsNewWindow(req) }
    function triggerWebAction(a)  { if (loader.item) loader.item.triggerWebAction(a) }
    function grabToImage(callback, targetSize) {
        ensureLoaded()
        if (loader.item && typeof loader.item.grabToImage === "function") {
            loader.item.grabToImage(callback, targetSize)
            return
        }
        if (callback)
            callback({ url: "", image: null })
    }

    function detachView() {
        if (loader.item)
            loader.item.detachView()
    }

    /// Host-side Retry — ensure the Backend is loaded, then forward.
    function downloadUrl(url, suggestedFileName, token) {
        ensureLoaded()
        if (loader.item && loader.item.downloadUrl)
            loader.item.downloadUrl(url, suggestedFileName || "", token || "")
        else
            console.warn("LazyWebViewAdapter: downloadUrl unavailable")
    }

    onUrlChanged: {
        if (loader.item && loader.item.url !== url)
            loader.item.url = url
    }

    Loader {
        id: loader
        anchors.fill: parent
        onLoaded: {
            if (root.url.toString()) loader.item.url = root.url
            root.syncFromAdapterItem()
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load WebViewAdapter")
            }
        }

        readonly property string adapterPath: SQUtils.Utils.isMobile
            ? "MobileWebViewAdapter.qml"
            : "WebViewAdapter.qml"
    }

    Connections {
        target: loader.item
        function onUrlChanged() {
            if (root.url !== loader.item.url) root.url = loader.item.url
        }
        function onLinkHovered(hoveredUrl)             { root.linkHovered(hoveredUrl) }
        function onWindowCloseRequested()              { root.windowCloseRequested() }
        function onDownloadRequested(download, token)  { root.downloadRequested(download, token) }
        function onLinkLongPressed(linkUrl, imageUrl, position) {
            root.linkLongPressed(linkUrl, imageUrl, position)
        }
        function onNewWindowRequested(makeCurrent, requestedUrl, callback) {
            root.newWindowRequested(makeCurrent, requestedUrl, callback)
        }
        function onCertificateError(error)             { root.certificateError(error) }
        function onJavaScriptDialogRequested(request)  { root.javaScriptDialogRequested(request) }
        function onFindTextFinished(result)            { root.findTextFinished(result) }
        function onDevToolsToggled(enabled)            { root.devToolsToggled(enabled) }
        function onTitleChanged()                      { root.syncFromAdapterItem() }
        function onIconChanged()                       { root.syncFromAdapterItem() }
        function onHtmlPageLoadedChanged()             { root.syncFromAdapterItem() }
    }
}

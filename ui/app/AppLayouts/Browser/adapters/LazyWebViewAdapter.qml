import QtQuick

AbstractWebView {
    id: root

    // -------------------------------------------------------------------------
    // AbstractWebView required capability flags – same as WebViewAdapter so that
    // toolbar/menu bindings (zoom, find, incognito …) work from the moment the
    // tab is created, even before a WebEngineView is instantiated.
    // -------------------------------------------------------------------------
    supportsZoom:       true
    supportsDevTools:   true
    supportsFindInPage: true
    supportsIncognito:  true
    supportsHistory:    true
    hasNativeFindPanel: false

    // -------------------------------------------------------------------------
    // Proxied state – defaults while loader is inactive, live values once loaded.
    // Must redeclare each inherited readonly property from AbstractWebView as
    // `readonly property … : …` (simple assignment lines are invalid on readonly).
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // One-shot imperative activation: loader.active is flipped to true once and
    // never back, so the inner WebViewAdapter is never destroyed (e.g. url = ""
    // after a page loaded won't lose history or scroll state).
    // When to load is driven by BrowserWebViewContext (ensureLoaded): address bar,
    // tab switch, createEmptyTab for the foreground tab — not StackLayout attached
    // properties (avoids races when the stack is hidden behind EmptyWebPage overlay).
    // Same for download tabs: no WebEngineView until ensureLoaded (non-empty URL / navigation).
    // -------------------------------------------------------------------------
    /// Called from BrowserWebViewContext when this tab should materialise WebEngineView.
    function ensureLoaded() {
        if (!loader.active)
            loader.active = true
    }

    // -------------------------------------------------------------------------
    // Function overrides – forward to inner adapter when alive, else no-op.
    // loadUrl() also works as the primary activation path.
    // -------------------------------------------------------------------------
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

    // Push address-bar / programmatic URL changes into the inner adapter once it
    // exists. The initial URL is set in the sourceComponent's Component.onCompleted
    // so it fires after the item is fully constructed.
    onUrlChanged: {
        if (loader.item && loader.item.url !== url)
            loader.item.url = url
    }

    // -------------------------------------------------------------------------
    // Inner WebViewAdapter, created on demand.
    // -------------------------------------------------------------------------
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
            supportsZoom:                true
            supportsDevTools:            true
            supportsFindInPage:          true
            supportsIncognito:           true
            supportsHistory:             true
            hasNativeFindPanel:          false

            // Set initial URL when the component is constructed (not as a binding,
            // because WebEngine navigation breaks QML bindings on the url property).
            Component.onCompleted: if (root.url.toString()) url = root.url

            // Push browser-driven navigation (link clicks, redirects) back to the
            // outer wrapper so callers observing root.url stay up to date.
            onUrlChanged: { if (root.url !== url) root.url = url }
        }
    }

    // -------------------------------------------------------------------------
    // Signal forwarding from inner adapter.
    // -------------------------------------------------------------------------
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

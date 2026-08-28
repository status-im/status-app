import QtQuick

/**
 * Stand-in for the per-platform adapter LazyWebViewAdapter loads, with no
 * QtWebEngine import. Point adapterPath at it with Qt.resolvedUrl().
 */
Item {
    id: root

    // Set by LazyWebViewAdapter.ensureLoaded() through setSource properties.
    property var profileParams: null
    property string uid: ""
    property var bookmarksStore: null
    property var webChannel: null
    property bool enableJsLogs: false
    property var localAccountSensitiveSettings: null
    property bool devToolsEnabled: false
    property bool freeze: false
    property var profileManager: null

    // Proxied state LazyWebViewAdapter reads back.
    property url url: ""
    property string title: ""
    property url icon: ""
    property bool htmlPageLoaded: false
    property bool loading: false
    property bool canGoBack: false
    property bool canGoForward: false
    property real loadProgress: 0
    property real zoomFactor: 1.0
    property var history: null
    property var scrollPosition: Qt.point(0, 0)
    property bool clearing: false

    property bool supportsZoom: true
    property bool supportsDevTools: true
    property bool supportsFindInPage: true
    property bool supportsIncognito: true
    property bool supportsHistory: true
    property bool hasNativeFindPanel: false
    property bool clearSiteDataSupported: true

    // LazyWebViewAdapter's Connections block warns on any it cannot find.
    signal linkHovered(string hoveredUrl)
    signal windowCloseRequested()
    signal downloadRequested(var download, string token)
    signal linkLongPressed(url linkUrl, url imageUrl, point position)
    signal newWindowRequested(bool makeCurrent, url requestedUrl, var callback)
    signal certificateError(var error)
    signal javaScriptDialogRequested(var request)
    signal findTextFinished(var result)
    signal devToolsToggled(bool enabled)
    signal renderProcessTerminated(int status, int exitCode)

    property int reloadCalls: 0
    property var loadedUrls: []

    function reload() { root.reloadCalls += 1 }
    function loadUrl(u) { root.url = u; root.loadedUrls = root.loadedUrls.concat([String(u)]) }
    function goBack() {}
    function goForward() {}
    function goBackOrForward(offset) {}
    function stop() {}
    function forceReload() {}
    function detachView() {}
    function triggerWebAction(action) {}
    function runJavaScript(script, callback) {}

    /// Convenience: the Backend values a WebEngine crash reports.
    function simulateCrash() { root.renderProcessTerminated(2 /*Crashed*/, 133) }
}

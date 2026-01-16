import QtQuick

import StatusQ.CustomWebView 1.0

import AppLayouts.Browser.stores as BrowserStores

AbstractWebView {
    id: root

    required property BrowserStores.BookmarksStore bookmarksStore
    required property BrowserStores.DownloadsStore downloadsStore

    property var findBarComp
    property var favMenu
    property var addFavModal
    property var downloadsMenu
    property var determineRealURLFn: function(url) { return url }
    property bool enableJsLogs: false
    property bool isDownloadView: false

    readonly property bool offTheRecord: false

    property alias url: backend.url
    readonly property alias loading: backend.loading
    readonly property string title: ""
    readonly property bool canGoBack: false
    readonly property bool canGoForward: false
    readonly property real loadProgress: backend.loading ? 50 : 100
    readonly property alias htmlPageLoaded: backend.loaded

    readonly property var history: null
    readonly property url icon: ""

    readonly property bool supportsZoom: false
    readonly property bool supportsDevTools: false
    readonly property bool supportsFindInPage: false
    readonly property bool supportsIncognito: false
    readonly property bool supportsHistory: false

    readonly property real zoomFactor: 1.0

    // DarwinWebViewBackend is now a QQuickItem that automatically tracks its own geometry
    DarwinWebViewBackend {
        id: backend
        anchors.fill: parent
        visible: root.visible
    }

    function loadUrl(newUrl) {
        backend.loadUrl(newUrl)
    }

    function goBack() {
        console.warn("DarwinWebViewAdapter: goBack not supported yet")
    }

    function goForward() {
        console.warn("DarwinWebViewAdapter: goForward not supported yet")
    }

    function goBackOrForward(offset) {
        console.warn("DarwinWebViewAdapter: goBackOrForward not supported yet")
    }

    function reload() {
        if (backend.url.toString() !== "") {
            backend.loadUrl(backend.url)
        }
    }

    function stop() {
        console.warn("DarwinWebViewAdapter: stop not supported yet")
    }

    function findText(text, flags) {
        // No-op: find in page not supported
    }

    function changeZoomFactor(factor) {
        // No-op: zoom not supported
    }

    function acceptAsNewWindow(request) {
        console.warn("DarwinWebViewAdapter: acceptAsNewWindow not supported")
    }

    function triggerWebAction(action) {
        switch (action) {
            case AbstractWebView.WebAction.Back:
                goBack()
                break
            case AbstractWebView.WebAction.Forward:
                goForward()
                break
            case AbstractWebView.WebAction.Stop:
                stop()
                break
            case AbstractWebView.WebAction.Reload:
                reload()
                break
            default:
                console.warn("DarwinWebViewAdapter: Web action not supported:", action)
        }
    }
}

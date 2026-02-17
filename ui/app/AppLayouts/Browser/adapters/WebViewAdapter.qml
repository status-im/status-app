import QtQuick
import QtWebEngine

import StatusQ.Core.Theme

import AppLayouts.Browser.views

AbstractWebView {
    id: root

    property bool enableJsLogs: false
    required property var localAccountSensitiveSettings
    property var bookmarksStore
    property var downloadsStore

    property var profile: ProfileManager.getProfile(root.profileParams)

    // Expose internal WebEngineView properties
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
    readonly property alias scrollPosition: webView.scrollPosition

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
    function detachView() {
        // Detach internal views from scene graph before destroy.
        webView.webChannel = null
        devToolsView.inspectedView = null
        webView.stop()
        webView.visible = false
        webView.parent = null
        devToolsView.visible = false
        devToolsView.parent = null
    }
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
                console.warn("WebViewAdapter: Unknown web action:", action)
        }
    }

    WebEngineView {
        id: webView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.devToolsEnabled ? devToolsView.top : parent.bottom
        focus: true

        property bool htmlPageLoaded: false
        backgroundColor: Theme.palette.background

        settings.autoLoadImages: root.localAccountSensitiveSettings.autoLoadImages
        settings.javascriptEnabled: root.localAccountSensitiveSettings.javaScriptEnabled
        settings.errorPageEnabled: root.localAccountSensitiveSettings.errorPageEnabled
        settings.pluginsEnabled: root.localAccountSensitiveSettings.pluginsEnabled
        settings.autoLoadIconsForPage: root.localAccountSensitiveSettings.autoLoadIconsForPage
        settings.touchIconsEnabled: root.localAccountSensitiveSettings.touchIconsEnabled
        settings.webRTCPublicInterfacesOnly: root.localAccountSensitiveSettings.webRTCPublicInterfacesOnly
        settings.pdfViewerEnabled: root.localAccountSensitiveSettings.pdfViewerEnabled
        settings.focusOnNavigationEnabled: true
        settings.forceDarkMode: Application.styleHints.colorScheme === Qt.ColorScheme.Dark

        webChannel: root.webChannel
        profile: root.profile

        onQuotaRequested: function(request) {
            if (request.requestedSize <= 5 * 1024 * 1024)
                request.accept()
            else
                request.reject()
        }
        onRegisterProtocolHandlerRequested: function(request) {
            console.log("accepting registerProtocolHandler request for "
                        + request.scheme + " from " + request.origin)
            request.accept()
        }
        onRenderProcessTerminated: function(terminationStatus, exitCode) {
            var status = ""
            switch (terminationStatus) {
            case WebEngineView.NormalTerminationStatus:
                status = "(normal exit)"
                break
            case WebEngineView.AbnormalTerminationStatus:
                status = "(abnormal exit)"
                break
            case WebEngineView.CrashedTerminationStatus:
                status = "(crashed)"
                break
            case WebEngineView.KilledTerminationStatus:
                status = "(killed)"
                break
            }
            console.warn("Render process exited with code " + exitCode + " " + status)
        }
        onSelectClientCertificate: function(selection) {
            selection.certificates[0].select()
        }
        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                webView.htmlPageLoaded = false
            }
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                webView.htmlPageLoaded = true
            }
        }
        onLoadProgressChanged: function(progress) {
            if (progress >= 10)
                webView.htmlPageLoaded = true
        }
        onNavigationRequested: function(request) {
            if (request.url.toString().startsWith("file:/")) {
                console.log("Local file browsing is disabled")
                request.reject()
            }
        }
        onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
            const isOurScript = ScriptUtils.isOurInjectedScript(sourceID, root.profile)
            if (isOurScript || root.enableJsLogs)
                console.log("[WebEngine]", sourceID + ":" + lineNumber, message)
        }
        onLinkHovered: (hoveredUrl) => root.linkHovered(hoveredUrl)
        onWindowCloseRequested: root.windowCloseRequested()
        onNewWindowRequested: (request) => {
            if (!request.userInitiated) {
                console.warn("Warning: Blocked a popup window.")
            } else {
                const makeCurrent = request.destination !== WebEngineNewWindowRequest.InNewBackgroundTab
                root.newWindowRequested(makeCurrent, request.requestedUrl, (tab) => tab.acceptAsNewWindow(request))
            }
        }
        onCertificateError: (error) => root.certificateError(error)
        onJavaScriptDialogRequested: (request) => root.javaScriptDialogRequested(request)
        onFindTextFinished: (result) => root.findTextFinished(result)
        onPermissionRequested: function(permission) {
            if (permission.permissionType === WebEnginePermission.PermissionType.ClipboardReadWrite) {
                console.log("Clipboard access granted")
                permission.grant()
            }
        }
    }

    Connections {
        target: root.profile
        function onDownloadRequested(download) {
            // Profile emits for all tabs sharing it; forward only owner view.
            if (download?.view && download.view !== webView)
                return
            // For viewless downloads, only visible adapter forwards to avoid fan-out.
            if (!download?.view && !root.visible)
                return
            root.downloadRequested(download)
        }
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
        // This connection is needed because changing profileParams.offTheRecord doesn't trigger the root.profile update
        target: root.profileParams
        function onOffTheRecordChanged() {
            root.profile = ProfileManager.getProfile(root.profileParams)
        }
        function onUserAgentChanged() {
            root.profile = ProfileManager.getProfile(root.profileParams)
        }
        function onScriptsChanged() {
            root.profile = ProfileManager.getProfile(root.profileParams)
        }
        function onUserIdChanged() {
            root.profile = ProfileManager.getProfile(root.profileParams)
        }
    }
}

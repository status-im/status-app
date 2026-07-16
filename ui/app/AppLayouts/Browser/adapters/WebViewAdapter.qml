import QtQuick
import QtQml
import QtWebEngine

import StatusQ.Core.Theme
import StatusQ.Internal

import AppLayouts.Browser.views

AbstractWebView {
    id: root

    required property var profileManager

    property var profile: root.profileParams
        ? root.profileManager.getOrCreateStorageProfile(root.profileParams)
        : null

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
    supportsZoom: true
    supportsDevTools: true
    supportsFindInPage: true
    supportsIncognito: true
    supportsHistory: true
    hasNativeFindPanel: false
    // Cookies (incl. HttpOnly) via BrowserProfileUtils; DOM storage via site_utils.js.
    clearSiteDataSupported: true

    // Unified clear lifecycle (see CONTEXT: Clearing). Mutual exclusion + nav guard.
    readonly property int _clearIdle: 0
    readonly property int _clearSite: 1
    readonly property int _clearProfile: 2
    readonly property int _clearAwaitingReload: 3
    property int _clearState: _clearIdle
    property url _clearingUrl
    clearing: _clearState !== _clearIdle

    // Override functions
    function loadUrl(newUrl) { webView.url = newUrl }
    function goBack() { webView.goBack() }
    function goForward() { webView.goForward() }
    function goBackOrForward(offset) { webView.goBackOrForward(offset) }
    function reload() { webView.reload() }
    function stop() { webView.stop() }
    function forceReload() { webView.triggerWebAction(WebEngineView.ReloadAndBypassCache) }

    function _sameOrigin(a, b) {
        if (!a || !b || !a.toString() || !b.toString())
            return false
        return a.scheme === b.scheme && a.host === b.host && a.port === b.port
    }

    function _endClear() {
        root._clearState = root._clearIdle
        root._clearingUrl = ""
        _clearFallbackTimer.stop()
    }

    function _beginAwaitingReloadWipe() {
        // Do not wipe DOM / reload a different origin than the one we cleared.
        if (!root._sameOrigin(webView.url, root._clearingUrl)) {
            root._endClear()
            return
        }
        root._clearState = root._clearAwaitingReload
        _clearFallbackTimer.restart()
        root._wipeCurrentOriginDomAndReload()
    }

    // Native per-site cookies, then site_utils.js for current-origin DOM + reload.
    function clearSiteData() {
        if (root._clearState !== root._clearIdle || !root.profile)
            return
        const siteUrl = webView.url
        if (!siteUrl.toString())
            return
        root._clearState = root._clearSite
        root._clearingUrl = siteUrl
        _clearFallbackTimer.restart()
        // Pass `root` so only this adapter reacts to clearSiteDataCompleted.
        BrowserProfileUtils.clearSiteData(root.profile, siteUrl, root)
    }

    function _onNativeSiteClearDone(requester) {
        if (requester !== root)
            return
        if (root._clearState !== root._clearSite)
            return
        root._beginAwaitingReloadWipe()
    }

    // Profile-wide cookies + HTTP cache, then current-origin DOM via site_utils.js.
    function clearBrowsingData() {
        if (root._clearState !== root._clearIdle || !root.profile)
            return
        root._clearState = root._clearProfile
        root._clearingUrl = webView.url
        _clearFallbackTimer.restart()
        BrowserProfileUtils.clearBrowsingData(root.profile)
    }

    function runJavaScript(script, callback) {
        if (callback === undefined)
            webView.runJavaScript(script)
        else
            webView.runJavaScript(script, callback)
    }

    function _onNativeBrowsingClearDone() {
        // Profile signal fans out to every tab; only the initiator finishes.
        if (root._clearState !== root._clearProfile)
            return
        root._beginAwaitingReloadWipe()
    }

    function _wipeCurrentOriginDomAndReload() {
        const expected = root._clearingUrl
        webView.runJavaScript(
            "(function(){ if (window.StatusSiteUtils) { window.StatusSiteUtils.clearSiteDataAndReload(); return true; } return false; })()",
            function(ok) {
                if (root._clearState !== root._clearAwaitingReload)
                    return
                if (!root._sameOrigin(webView.url, expected)) {
                    root._endClear()
                    return
                }
                if (!ok) {
                    // GET navigate — ReloadAndBypassCache can re-POST and re-Set-Cookie.
                    if (expected && expected.toString())
                        webView.url = expected
                }
            }
        )
    }
    function findText(text, flags) { webView.findText(text, flags) }
    function changeZoomFactor(factor) { webView.zoomFactor = factor }
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
        anchors.left: parent?.left
        anchors.right: parent?.right
        anchors.top: parent?.top
        anchors.bottom: root.devToolsEnabled ? devToolsView.top : parent?.bottom
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
                // Expected GET after clear: unblock once navigation starts.
                if (root._clearState === root._clearAwaitingReload
                        && root._sameOrigin(loadRequest.url, root._clearingUrl)) {
                    root._endClear()
                }
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
            if (root._clearState === root._clearSite
                    || root._clearState === root._clearProfile) {
                // Block user/site navigation while native clear is in flight.
                request.reject()
                return
            }
            if (root._clearState === root._clearAwaitingReload) {
                // Allow only the expected same-origin GET reload after wipe.
                if (!root._sameOrigin(request.url, root._clearingUrl)) {
                    request.reject()
                    return
                }
            }
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
        function onClearHttpCacheCompleted() { root._onNativeBrowsingClearDone() }
    }

    Connections {
        target: BrowserProfileUtils
        function onClearSiteDataCompleted(requester) { root._onNativeSiteClearDone(requester) }
    }

    // Safety net: unblock if native completion or expected reload never arrives.
    Timer {
        id: _clearFallbackTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root._clearState === root._clearSite
                    || root._clearState === root._clearProfile) {
                // Native phase stuck — still try DOM wipe if origin matches.
                root._beginAwaitingReloadWipe()
                return
            }
            if (root._clearState === root._clearAwaitingReload)
                root._endClear()
        }
    }

    WebEngineView {
        id: devToolsView
        anchors.left: parent?.left
        anchors.right: parent?.right
        anchors.bottom: parent?.bottom
        height: root.devToolsEnabled ? root.devToolsHeight : 0
        visible: root.devToolsEnabled
        inspectedView: root.devToolsEnabled ? webView : null
        settings.forceDarkMode: Application.styleHints.colorScheme === Qt.ColorScheme.Dark

        onWindowCloseRequested: root.devToolsToggled(false)
    }

    Binding {
        // Always apply a non-empty UA. Setting httpUserAgent to "" after a
        // custom override does not restore the Chromium default — use the
        // snapshot captured at profile creation instead.
        when: !!(root.profile && root.profileParams && root.profileManager)
        target: root.profile
        property: "httpUserAgent"
        value: root.profileParams.userAgent || root.profileManager.defaultHttpUserAgent
    }

    function applyProfileScripts() {
        if (!root.profile || !root.profile.userScripts || !root.profileParams)
            return
        root.profile.userScripts.collection = root.profileManager.scriptListForParams(root.profileParams)
    }

    // Qt does not emit *Changed for the initial property value — only for later
    // changes. Without onCompleted, userScripts (site_utils, dapp injectors) are
    // never installed when profile is already set at construction time.
    Component.onCompleted: applyProfileScripts()
    onProfileChanged: applyProfileScripts()

    Connections {
        target: root.profileParams
        function onScriptsChanged() {
            root.applyProfileScripts()
        }
    }
}

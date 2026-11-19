import QtQuick

import AppLayouts.Browser.webview

QtObject {
    id: root

    required property var webViewContext
    required property var tabs
    required property var defaultProfileParams
    required property var determineRealURL
    required property var preferencesStore
    required property Item currentWebView

    // Opened Files reachable after a restart (desktop) keep their Tabs.
    property bool keepsOpenedFiles: false
    // Reopens a saved Opened File's Tab in place; false when it cannot open.
    property var restoreOpenedFileFn: function(tab) { return false }

    property Item previousWebView: null
    property var persistedTabs: []
    property bool _shuttingDown: false

    readonly property bool currentWebViewLoaded: currentWebView ? currentWebView.htmlPageLoaded : false

    readonly property SnapshotPersister snapshotPersister: SnapshotPersister {
        preferencesStore: root.preferencesStore
    }

    readonly property Timer _saveSessionTimer: Timer {
        interval: 700
        repeat: false
        onTriggered: {
            if (root._shuttingDown)
                return
            root.saveSession()
        }
    }

    readonly property Connections _currentWebViewWatch: Connections {
        target: root.currentWebView
        function onTitleChanged() { root.scheduleSaveSession() }
        function onIconChanged() { root.scheduleSaveSession() }
    }

    function setPersisted(tabs) {
        persistedTabs = Array.isArray(tabs) ? tabs.slice() : []
    }

    function recordForWebView(webView) {
        if (!webView)
            return null
        return BrowserSessionUtils.findSavedTab(persistedTabs, String(webView.uid || "").trim())
    }

    function seedWebView(webView, restoreHint) {
        if (!webView)
            return

        const persisted = recordForWebView(webView)
        const title = BrowserSessionUtils.resolveTitle(restoreHint?.title || "", persisted)
        const icon = BrowserSessionUtils.resolveIcon(restoreHint?.icon || "", persisted)

        if (title)
            webView.title = title
        if (icon)
            webView.icon = icon
    }

    function displayTitle(webView, isStartPage) {
        return BrowserSessionUtils.displayTitle(webView, recordForWebView(webView), {
            isStartPage: !!isStartPage,
            startPageLabel: qsTr("Start Page"),
            emptyLabel: qsTr("New Tab")
        })
    }

    function displayIcon(webView) {
        return webView ? BrowserSessionUtils.resolveIcon(webView.icon, recordForWebView(webView)) : ""
    }

    function buildTabDto(webView) {
        return BrowserSessionUtils.buildTabDto(webView, persistedTabs, determineRealURL,
                                               keepsOpenedFiles)
    }

    function scheduleSaveSession() {
        if (_shuttingDown)
            return
        if (!preferencesStore.getRestoreOpenTabs())
            return
        _saveSessionTimer.restart()
    }

    function saveSession() {
        if (_shuttingDown)
            return
        if (!preferencesStore.getRestoreOpenTabs())
            return

        const tabsModel = []
        for (let i = 0; i < tabs.count; i++) {
            const dto = buildTabDto(webViewContext.getWebView(i))
            if (dto)
                tabsModel.push(dto)
        }

        preferencesStore.setOpenTabs(tabsModel)
        preferencesStore.setCurrentTabIndex(tabs.currentIndex)
        setPersisted(tabsModel)
    }

    function purgeSnapshots() {
        const validUids = persistedTabs
            .map(tab => String(tab.uuid || "").trim())
            .filter(uid => uid.length > 0)
        preferencesStore.purgeSnapshots(validUids)
    }

    function openDefaultTab() {
        webViewContext.createEmptyTab(defaultProfileParams, true)
        // For Devs: Uncomment the next line if you want to use the simpledapp on first load
        // tab.url = determineRealURL("https://simpledapp.eth");
    }

    function restoreSession() {
        const tabsToRestore = preferencesStore.getRestoreOpenTabs()
            ? preferencesStore.getOpenTabs()
            : []
        setPersisted(tabsToRestore)
        purgeSnapshots()

        if (tabsToRestore.length === 0) {
            openDefaultTab()
            return
        }

        const savedIndex = preferencesStore.getCurrentTabIndex()
        let currentIndex = -1
        let browsingParams = null
        tabsToRestore.forEach((tab, index) => {
            if (tab.openedFile) {
                if (!keepsOpenedFiles || !restoreOpenedFileFn(tab))
                    return
            } else {
                const view = webViewContext.createEmptyTab(
                    browsingParams || defaultProfileParams,
                    false,
                    false,
                    determineRealURL(tab.url),
                    tab.title,
                    tab.icon,
                    tab.uuid
                )
                browsingParams = browsingParams || view?.profileParams
            }
            if (index <= savedIndex)
                currentIndex = tabs.count - 1
        })

        Qt.callLater(() => {
            if (tabs.count === 0) {
                openDefaultTab()
                return
            }
            if (currentIndex >= 0 && currentIndex < tabs.count)
                tabs.activateTab(currentIndex)
            webViewContext.ensureCurrentWebViewLoaded()
        })
    }

    function _persistAndScheduleIfLoaded() {
        if (_shuttingDown)
            return
        if (currentWebView && currentWebViewLoaded) {
            snapshotPersister.schedulePersist(currentWebView)
            scheduleSaveSession()
        }
    }

    Component.onDestruction: {
        root._shuttingDown = true
        _saveSessionTimer.stop()
    }

    onCurrentWebViewChanged: {
        if (previousWebView && previousWebView !== currentWebView) {
            if (previousWebView.htmlPageLoaded)
                snapshotPersister.persistSnapshot(previousWebView)
            scheduleSaveSession()
        }

        previousWebView = currentWebView
        _persistAndScheduleIfLoaded()
    }

    onCurrentWebViewLoadedChanged: _persistAndScheduleIfLoaded()
}

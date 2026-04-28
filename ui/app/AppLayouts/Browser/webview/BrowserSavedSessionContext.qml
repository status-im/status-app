import QtQuick

QtObject {
    id: root

    required property var webViewContext
    required property var tabs
    required property var defaultProfileParams
    required property var determineRealURL

    function determineFaviconURL(iconUrl) {
        return iconUrl ? iconUrl.toString().replace("image://favicon/", "") : ""
    }

    function saveSession() {
        if (!BrowserUiSettings.restoreOpenTabs)
            return

        var tabsModel = []

        for (let i = 0; i < tabs.count; i++) {
            const webView = webViewContext.getWebView(i)
            if (!!webView && !webView.offTheRecord) {
                const raw = webView.url.toString()
                const url = determineRealURL(raw)
                if (!!url) {
                    const icon = determineFaviconURL(webView.icon)
                    tabsModel.push({url: url, title: webView.title || "", icon: icon})
                }
            }
        }
        BrowserUiSettings.openTabs = tabsModel
        BrowserUiSettings.currentTabIndex = tabs.currentIndex
        BrowserUiSettings.sync()
    }

    function getTabsInfo() {
        var list = []
        try {
            list = JSON.parse(JSON.stringify(BrowserUiSettings.openTabs || [])) || []
        } catch (e) {
            list = []
        }
        if (!Array.isArray(list))
            list = []
        return list.filter(t => t && String(t.url || "").trim() !== "")
    }

    function openDefaultTab() {
        const tab = webViewContext.createEmptyTab(defaultProfileParams, true)
        // For Devs: Uncomment the next line if you want to use the simpledapp on first load
        // tab.url = determineRealURL("https://simpledapp.eth");
    }

    function restoreSession() {
        const tabsToRestore = BrowserUiSettings.restoreOpenTabs ? getTabsInfo() : []
        if (tabsToRestore.length === 0) {
            openDefaultTab()
            return
        }
        tabsToRestore.forEach((t, i) => {
            const profileParams = (i === 0) ? defaultProfileParams : webViewContext.getWebView(0).profileParams
            webViewContext.createEmptyTab(
                profileParams, false, false,
                determineRealURL(t.url), t.title, t.icon)
        })
        const savedIndex = BrowserUiSettings.currentTabIndex
        Qt.callLater(() => {
            if (tabs.count === 0) {
                openDefaultTab()
                return
            }
            if (savedIndex >= 0 && savedIndex < tabs.count)
                tabs.activateTab(savedIndex)
            webViewContext.ensureCurrentWebViewLoaded()
        })
    }
}

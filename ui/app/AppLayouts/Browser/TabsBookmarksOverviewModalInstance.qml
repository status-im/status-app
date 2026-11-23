import StatusQ.Core.Theme

import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview

TabsBookmarksOverviewModal {
    id: root

    required property BrowserStores.BookmarksStore bookmarksStore
    required property BrowserStores.BrowserRootStore browserRootStore
    required property BrowserStores.BrowserPreferencesStore browserPreferencesStore
    required property BrowserWebViewContext webViewContext
    required property BrowserSavedSessionContext savedSessionContext

    bookmarksModel: root.bookmarksStore.bookmarksModel

    getTitleFn: function(tabIndex) {
        const webView = root.webViewContext.getWebView(tabIndex)
        return root.savedSessionContext.displayTitle(webView, false)
    }
    getFaviconFn: function(tabIndex) {
        const webView = root.webViewContext.getWebView(tabIndex)
        if (!webView)
            return Assets.svg("globe")

        const icon = root.savedSessionContext.displayIcon(webView)
        return root.browserRootStore.determineRealURL(icon || Assets.svg("globe"))
    }
    getWebViewScreenshot: function (tabIndex, targetImage) {
        const webView = root.webViewContext.getWebView(tabIndex)
        if (!webView)
            return ""

        function grabImage() {
            root.savedSessionContext.snapshotPersister.grabSnapshot(webView, result => {
                if (result && result.url)
                    targetImage.source = result.url
            })
        }

        function grabImageWhenLoaded() {
            if (webView.htmlPageLoaded)
                grabImage()
        }

        const isCurrentTab = tabIndex === root.currentTabIndex
        if (!isCurrentTab) {
            const cached = root.browserPreferencesStore.getSnapshot(webView.uid)
            if (cached) {
                targetImage.source = cached
                return ""
            }
        }

        if (webView.htmlPageLoaded)
            grabImage()
        else
            webView.htmlPageLoadedChanged.connect(grabImageWhenLoaded)
    }

    onDeleteBookmarkRequested: url => root.bookmarksStore.deleteBookmark(url)
}

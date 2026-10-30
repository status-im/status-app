import QtQuick
import QtTest

import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview

Item {
    id: root

    width: 400
    height: 200

    Component {
        id: bookmarksStoreComponent

        BrowserStores.BookmarksStore {}
    }

    Component {
        id: webViewComponent

        QtObject {
            property url url: ""
            property string title: ""
        }
    }

    Component {
        id: favoritesContextComponent

        BrowserFavoritesContext {
            required property var webView
            currentWebView: webView
            shouldShowFavoritesBar: true
        }
    }

    TestCase {
        name: "BrowserBookmarks"
        when: windowShown

        function makeContext(url, store, showBar) {
            const webView = createTemporaryObject(webViewComponent, root, { url: url })
            return createTemporaryObject(favoritesContextComponent, root, {
                webView: webView,
                bookmarksStore: store,
                shouldShowFavoritesBar: showBar !== false
            })
        }

        function storeWithBookmark(url, name) {
            const store = createTemporaryObject(bookmarksStoreComponent, root)
            store.addBookmark(url, name)
            return store
        }

        function test_favoritesBarActiveWhenBookmarksExist() {
            const store = storeWithBookmark("https://status.app/", "Status App")
            const ctx = makeContext("https://unlisted.example/", store)
            verify(ctx.favoritesBarActive)
        }

        function test_currentTabIsBookmarkWhenUrlMatches() {
            const store = storeWithBookmark("https://status.app/", "Status App")
            const ctx = makeContext("https://status.app/", store)
            verify(ctx.currentTabIsBookmark)
        }

        function test_addBookmarkThenDetectsAsFavorite() {
            const store = createTemporaryObject(bookmarksStoreComponent, root)
            const webView = createTemporaryObject(webViewComponent, root, {
                url: "https://new-favorite.example/"
            })
            const ctx = createTemporaryObject(favoritesContextComponent, root, {
                webView: webView,
                bookmarksStore: store
            })
            verify(!ctx.currentTabIsBookmark)
            store.addBookmark("https://new-favorite.example/", "New favorite")
            verify(ctx.currentTabIsBookmark)
        }
    }
}

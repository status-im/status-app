import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores

AddFavoriteModal {
    id: root

    required property BrowserStores.BookmarksStore bookmarksStore

    onAddBookmarkRequested: (url, name) => root.bookmarksStore.addBookmark(url, name)
    onEditBookmarkRequested: (oldUrl, newUrl, newName) => root.bookmarksStore.updateBookmark(oldUrl, newUrl, newName)
    onDeleteBookmarkRequested: url => root.bookmarksStore.deleteBookmark(url)
}

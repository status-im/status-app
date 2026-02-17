import QtQml
import QtQml.Models

QtObject {
    id: root

    property var bookmarksModel: ListModel {
        ListElement {
            name: "Status Hub"
            url: "https://hub.status.network/" // Constants.browserDefaultHomepage
        }
        ListElement {
            name: "Seznam"
            url: "https://www.seznam.cz/"
        }
    }

    function addBookmark(url, name) {
        bookmarksModel.append({url, name})
    }

    function deleteBookmark(url) {
        const idx = getBookmarkIndexByUrl(url)
        if (idx === -1)
            return
        bookmarksModel.remove(idx, 1)
    }

    function updateBookmark(originalUrl, newUrl, newName) {
        const idx = getBookmarkIndexByUrl(originalUrl)
        if (idx === -1)
            return
        bookmarksModel.set(idx, {"url": newUrl, "name": newName})
    }

    function getBookmarkIndexByUrl(url) {
        const count = bookmarksModel.count
        for (let i = 0; i < count; i++) {
            const item = bookmarksModel.get(i)
            if (!!item && item.url === url)
                return i
        }
        return -1
    }

    function getCurrentFavorite(url) {
        if (!url) {
            return null
        }
        const index = getBookmarkIndexByUrl(url)
        if (index === -1) {
            return null
        }

        return bookmarksModel.get(index)
    }
}

import QtQuick

import QtModelsToolkit

QtObject {
    id: root

    required property var currentWebView
    required property var bookmarksStore
    required property bool shouldShowFavoritesBar
    required property var openPopupFn
    required property var addFavoriteModal

    readonly property bool favoritesBarActive: shouldShowFavoritesBar &&
                                               bookmarksStore.bookmarksModel.ModelCount.count > 0
    readonly property var currentUrl: (currentWebView && currentWebView.url)
                                     ? currentWebView.url
                                     : ""
    readonly property string currentTitle: currentWebView ? currentWebView.title : ""

    readonly property var currentViewBookmarkEntry: ModelEntry {
        sourceModel: root.bookmarksStore.bookmarksModel
        key: "url"
        value: root.currentUrl ? root.currentUrl.toString() : ""
    }

    readonly property bool currentTabIsBookmark: currentViewBookmarkEntry.available &&
                                                 !!currentViewBookmarkEntry.item

    function buildAddFavoritePopupParams(modifyModal = false, fallbackItem = null) {
        var bookmarkItem = currentViewBookmarkEntry.available ? currentViewBookmarkEntry.item : null
        var sourceItem = fallbackItem || bookmarkItem
        var sourceUrl = sourceItem ? sourceItem.url : currentUrl
        var sourceName = sourceItem ? sourceItem.name : currentTitle
        return {
            modifiyModal: modifyModal,
            toolbarMode: true,
            ogUrl: sourceUrl,
            ogName: sourceName
        }
    }

    function openAddFavoritePopup(modifyModal = false, fallbackItem = null) {
        openPopupFn(addFavoriteModal, buildAddFavoritePopupParams(modifyModal, fallbackItem))
    }
}

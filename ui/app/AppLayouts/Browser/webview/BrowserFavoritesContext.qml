import QtQuick

import QtModelsToolkit

QtObject {
    id: root

    required property var currentWebView
    required property var bookmarksStore
    required property bool shouldShowFavoritesBar

    readonly property bool favoritesBarActive: shouldShowFavoritesBar &&
                                               bookmarksStore.bookmarksModel.ModelCount.count > 0
    readonly property string currentUrl: (currentWebView && currentWebView.url)
                                         ? currentWebView.url
                                         : ""
    readonly property string currentTitle: currentWebView ? currentWebView.title : ""

    readonly property var currentViewBookmarkEntry: ModelEntry {
        sourceModel: root.bookmarksStore.bookmarksModel
        key: "url"
        value: root.currentUrl || ""
    }

    readonly property bool currentTabIsBookmark: currentViewBookmarkEntry.available &&
                                                 !!currentViewBookmarkEntry.item
}

import QtQml

// TabsBookmarksOverviewModal.initialMode values, in their own type so that naming one does not load the modal
QtObject {
    enum Mode {
        OpenTabs,
        Bookmarks,
        Downloads
    }
}

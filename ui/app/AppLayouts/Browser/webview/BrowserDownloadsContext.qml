import QtQuick

QtObject {
    id: root

    required property var downloadsStore
    required property var tabsModel
    required property var getWebViewFn
    required property var removeViewFn
    required property var setFooterVisibleFn

    function handleDownloadRequest(download) {
        if (!download)
            return

        downloadsStore.addDownload(download)
        download.accept()
        setFooterVisibleFn(true)

        // Close tabs that were opened only to trigger a download.
        if (!download.view)
            return

        for (var i = 0; i < tabsModel.count; ++i) {
            var tab = getWebViewFn(i)
            if (tab === download.view && !tab.htmlPageLoaded && tab.title === "") {
                removeViewFn(i)
                break
            }
        }
    }

    function openDownloadFromList(downloadComplete, index) {
        if (downloadComplete)
            return downloadsStore.openFile(index)

        downloadsStore.openDirectory(index)
    }
}

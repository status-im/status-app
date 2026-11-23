import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores

DownloadRecordMenu {
    id: root

    required property BrowserStores.DownloadsStore downloadsStore

    onDismissRequested: root.downloadsStore.dismissRecordFromStrip(root.record)
    onShowInFolderRequested: root.downloadsStore.openDirectoryForRecord(root.record)
}

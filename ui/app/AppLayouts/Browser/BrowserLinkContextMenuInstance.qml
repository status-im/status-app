import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores

BrowserLinkContextMenu {
    id: root

    required property BrowserStores.DownloadsStore downloadsStore

    canShareLink: root.downloadsStore.canShareUrlString(root.linkUrl)

    onShareUrlRequested: targetUrl => root.downloadsStore.shareUrlString(targetUrl)
}

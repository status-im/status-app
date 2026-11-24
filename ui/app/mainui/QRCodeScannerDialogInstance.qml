import AppLayouts.stores as AppLayoutStores

import shared.popups

import utils

QRCodeScannerDialog {
    id: root

    required property AppLayoutStores.RootStore rootStore

    signal wcUriScanned(string uri)

    onTagFound: (tagType, tag) => {
        if (tagType === QRCodeScannerDialog.TagType.Address) {
            Global.sendToRecipientRequested(tag)
        } else if (tagType === QRCodeScannerDialog.TagType.Link) {
            if (Utils.isStatusDeepLink(tag)) {
                root.rootStore.activateStatusDeepLink(tag)
                return
            }
            Global.requestOpenLink(tag)
        } else if (tagType === QRCodeScannerDialog.TagType.WCUri) {
            root.wcUriScanned(tag)
        }
    }
}

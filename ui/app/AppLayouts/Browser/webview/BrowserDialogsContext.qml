import QtQuick
import StatusQ.Core.Utils as SQUtils

QtObject {
    id: root

    required property var networksStore
    required property var browserActivityStore
    required property var browserWalletStore
    required property Component jsDialogComponent
    required property Item dialogParent

    function openWalletMenu(browserWalletMenu) {
        // Initialize activity filters before opening popup.
        const activeChainIds = SQUtils.ModelUtils.modelToFlatArray(
                                 networksStore.activeNetworks, "chainId")
        if (activeChainIds.length > 0) {
            browserActivityStore.activityController.setFilterChainsJson(
                        JSON.stringify(activeChainIds), true)
        }

        const currentAddress = browserWalletStore.dappBrowserAccount.address
        browserActivityStore.activityController.setFilterAddressesJson(
                    JSON.stringify([currentAddress]))
        browserWalletMenu.createObject(dialogParent).open()
    }

    function openJsDialog(request) {
        request.accepted = true
        var dialog = jsDialogComponent.createObject(dialogParent, {"request": request})
        if (dialog)
            dialog.open()
    }
}

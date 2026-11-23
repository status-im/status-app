import QtQuick

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Wallet.popups.swap

SwapModal {
    id: swapModal

    required property AppLayoutStores.RootStore rootStore

    fnResolveENS: function(ensName, uuid) {
        swapModal.rootStore.resolveENS(ensName, uuid)
    }

    onClosed: swapModal.swapInputParamsForm.resetFormData()

    // the adaptor is created for this modal, which binds to it until deleted
    Component.onDestruction: swapModal.swapAdaptor.destroy()

    Connections {
        target: swapModal.rootStore

        function onEnsNameResolved(resolvedPubKey, resolvedAddress, uuid) {
            swapModal.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
        }
    }
}

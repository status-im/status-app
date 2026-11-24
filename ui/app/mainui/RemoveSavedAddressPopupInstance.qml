import AppLayouts.Wallet.popups as WalletPopups
import AppLayouts.Wallet.stores as WalletStores

WalletPopups.RemoveSavedAddressPopup {
    id: root

    required property WalletStores.RootStore walletRootStore

    onRemoveSavedAddress: {
        root.walletRootStore.deleteSavedAddress(root.address)
        root.close()
    }
}

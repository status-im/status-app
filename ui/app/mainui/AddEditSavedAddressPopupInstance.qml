import QtQuick

import AppLayouts.Wallet.popups as WalletPopups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppLayoutStores

WalletPopups.AddEditSavedAddressPopup {
    id: root

    required property AppLayoutStores.ContactsStore contactsStore
    required property WalletStores.RootStore walletRootStore
    required property var params

    contactsModel: root.contactsStore.contactsModel
    isChecksumValidForAddress: (address) => root.walletRootStore.isChecksumValidForAddress(address)
    getWalletAccount: (address) => root.walletRootStore.getWalletAccount(address)
    getSavedAddress: (address) => root.walletRootStore.getSavedAddress(address)
    remainingCapacityForSavedAddresses: () => root.walletRootStore.remainingCapacityForSavedAddresses()
    savedAddressNameExists: (name) => root.walletRootStore.savedAddressNameExists(name)

    onPopulateContactDetails: (publicKey) => root.contactsStore.populateContactDetails(publicKey)
    onFetchProfileShowcaseAccountsByAddressRequested: (address) => root.contactsStore.fetchProfileShowcaseAccountsByAddress(address)
    onCreateOrUpdateSavedAddressRequested: (name, address, ens, colorId) => root.walletRootStore.createOrUpdateSavedAddress(name, address, ens, colorId)

    Component.onCompleted: root.initWithParams(root.params)

    Connections {
        target: root.contactsStore

        function onProfileShowcaseAccountsByAddressFetched(accounts: string) {
            root.profileShowcaseAccountsByAddressFetched(accounts)
        }
    }
}

import QtQuick

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.panels

import StatusQ.Core

import shared.stores as SharedStores
import utils

RightTabBaseView {
    id: root

    signal sendToAddressRequested(string address)

    property WalletStores.RootStore rootStore
    property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore

    header: WalletSavedAddressesHeader {
        lastReloadedTime: !!root.rootStore.lastReloadTimestamp ?
                              LocaleUtils.formatRelativeTimestamp(
                                  root.rootStore.lastReloadTimestamp * 1000) : ""
        loading: root.rootStore.isAccountTokensReloading

        onReloadRequested: root.rootStore.reloadAccountBalances()
        onAddNewAddressClicked: Global.openAddEditSavedAddressesPopup({})
    }

    SavedAddresses {
        objectName: "savedAddressesArea"

        contactsStore: root.contactsStore
        networkConnectionStore: root.networkConnectionStore
        networksStore: root.networksStore

        onSendToAddressRequested: root.sendToAddressRequested(address)
    }
}

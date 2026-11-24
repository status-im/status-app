import QtQml

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.stores as WalletStores

import shared.stores

BuyCryptoModal {
    id: root

    required property WalletStores.BuyCryptoStore buyCryptoStore
    required property CurrenciesStore currencyStore
    required property AppLayoutStores.RootStore rootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property NetworksStore networksStore

    // Own the buy picker model's lifecycle here: created for this modal
    // instance and released when it is destroyed (avoids a per-open leak).
    readonly property var _tokenSelector: WalletStores.RootStore.tokensStore.createTokenSelectorModel(2)

    buyProvidersModel: root.buyCryptoStore.providersModel
    isBuyProvidersModelLoading: root.buyCryptoStore.areProvidersLoading
    formatCurrencyBalance: (amount) => root.currencyStore.formatCurrencyAmount(amount, root.currencyStore.currentCurrency)
    walletAccountsModel: root.rootStore.accounts
    tokenGroupsModel: root.walletAssetsStore.walletTokensStore.tokenGroupsModel
    groupedAccountAssetsModel: root.walletAssetsStore.groupedAccountAssetsModel
    networksModel: root.networksStore.activeNetworks
    tokenSelectorModel: _tokenSelector.model
    Component.onCompleted: {
        fetchProviders.connect(root.buyCryptoStore.fetchProviders)
        fetchProviderUrl.connect(root.buyCryptoStore.fetchProviderUrl)
        root.buyCryptoStore.providerUrlReady.connect(providerUrlReady)
    }
    Component.onDestruction: WalletStores.RootStore.tokensStore.releaseTokenSelectorModel(_tokenSelector.id)
}

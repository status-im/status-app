import AppLayouts.Chat.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Wallet.stores as WalletStores

import shared.stores

PaymentRequestModal {
    id: paymentRequestModal

    required property CurrenciesStore currencyStore
    required property NetworksStore networksStore

    signal paymentRequested(string address, string amount, string tokenKey,
                            string symbol, string tokenLogoUri)

    currentCurrency: paymentRequestModal.currencyStore.currentCurrency
    formatCurrencyAmount: paymentRequestModal.currencyStore.formatCurrencyAmount
    flatNetworksModel: paymentRequestModal.networksStore.activeNetworks
    accountsModel: WalletStores.RootStore.nonWatchAccounts

    // the selected chain's token groups, held while the modal shows it
    readonly property ChainTokenGroupsHolder chainTokenGroupsHolder: ChainTokenGroupsHolder {
        tokensStore: WalletStores.RootStore.tokensStore
        chainId: paymentRequestModal.selectedNetworkChainId
    }

    tokenGroupsForChainModel: chainTokenGroupsHolder.model
    searchResultModel: WalletStores.RootStore.tokensStore.searchResultModel

    onAllTokenGroupsAcquireRequested: WalletStores.RootStore.tokensStore.acquireAllTokenGroups()
    onAllTokenGroupsReleaseRequested: WalletStores.RootStore.tokensStore.releaseAllTokenGroups()

    onAccepted: {
        paymentRequested(selectedAccountAddress, amount,
                         selectedTokenKey, selectedSymbol,
                         selectedTokenLogoUri)
    }
}

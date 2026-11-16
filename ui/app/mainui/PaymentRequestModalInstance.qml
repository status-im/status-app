import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml
import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.popups
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.services.dapps
import mainui.popups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import shared.popups
import shared.popups.authentication
import shared.popups.authentication.stores 1.0 as AuthStores
import shared.popups.signing
import shared.popups.signing.stores 1.0 as SignStores
import shared.popups.keycard_new
import shared.popups.keycard_new.stores 1.0 as KeycardMgmtStores
import shared.status
import shared.stores
import shared.views
import shared.views.profile
import utils

PaymentRequestModal {
    id: paymentRequestModal

    required property Popups host

    signal paymentRequested(string address, string amount, string tokenKey,
                            string symbol, string tokenLogoUri)

    currentCurrency: paymentRequestModal.host.currencyStore.currentCurrency
    formatCurrencyAmount: paymentRequestModal.host.currencyStore.formatCurrencyAmount
    flatNetworksModel: paymentRequestModal.host.networksStore.activeNetworks
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
    destroyOnClose: true
}

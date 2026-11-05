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

BuyCryptoModal {
    id: root

    required property Popups host
    // Own the buy picker model's lifecycle here: created for this modal
    // instance and released when it is destroyed (avoids a per-open leak).
    readonly property var _tokenSelector: WalletStores.RootStore.tokensStore.createTokenSelectorModel(2)

    buyProvidersModel: root.host.buyCryptoStore.providersModel
    isBuyProvidersModelLoading: root.host.buyCryptoStore.areProvidersLoading
    formatCurrencyBalance: (amount) => root.host.currencyStore.formatCurrencyAmount(amount, root.host.currencyStore.currentCurrency)
    walletAccountsModel: root.host.rootStore.accounts
    tokenGroupsModel: root.host.walletAssetsStore.walletTokensStore.tokenGroupsModel
    groupedAccountAssetsModel: root.host.walletAssetsStore.groupedAccountAssetsModel
    networksModel: root.host.networksStore.activeNetworks
    tokenSelectorModel: _tokenSelector.model
    Component.onCompleted: {
        fetchProviders.connect(root.host.buyCryptoStore.fetchProviders)
        fetchProviderUrl.connect(root.host.buyCryptoStore.fetchProviderUrl)
        root.host.buyCryptoStore.providerUrlReady.connect(providerUrlReady)
    }
    Component.onDestruction: WalletStores.RootStore.tokensStore.releaseTokenSelectorModel(_tokenSelector.id)
    onClosed: destroy()
}

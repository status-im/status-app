import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Backpressure
import StatusQ.Core

import shared.stores as SharedStores
import shared.stores.send as SharedSendStores
import shared.popups

import AppLayouts.stores as AppStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores

import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups.swap
import utils

// Public API for this object are ONLY `stores` + the main `popupParent`
QtObject {
    id: root

    required property var popupParent

    // Stores definition:
    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property AppStores.ContactsStore contactsStore

    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedSendStores.TransactionStore transactionStore

    required property var/*TODO: Apply strong typing onces its no longer a singleton*/ walletRootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property WalletStores.CollectiblesStore walletCollectiblesStore
    required property WalletStores.TransactionStoreNew transactionStoreNew
    required property WalletStores.TokensStore tokensStore

    required property ChatStores.RootStore rootChatStore

    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property ProfileStores.PrivacyStore privacyStore

    required property Keychain keychain

    readonly property SwapModalHandler swapModalHandler: SwapModalHandler {

        property SwapInputParamsForm swapFormData: SwapInputParamsForm {}

        function launchSwap() {
            swapFormData.selectedAccountAddress =
                    SQUtils.ModelUtils.get(root.walletRootStore.nonWatchAccounts, 0, "address")
            swapFormData.selectedNetworkChainId =
                    SQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "layer", 1, "chainId")
            openSendModal(swapFormData, (popup) => {
                              popup.Component.destruction.connect(() => {
                                                                      swapFormData.resetFormData()
                                                                  })})
        }

        function launchSwapSpecific(data) {
            openSendModal(data, (popup) => {
                              popup.Component.destruction.connect(() => {
                                                                      data.resetFormData()
                                                                  })})
        }

        popupParent: root.popupParent
        walletAssetsStore: root.walletAssetsStore
        currencyStore: root.currencyStore
        networksStore: root.networksStore
        rootStore: root.rootStore
    }

    readonly property SendModalHandler sendModalHandler: SendModalHandler {

        // TODO: Remove this and adapt new mechanism to launch BuyModal as done for SendModal
        property BuyCryptoParamsForm buyFormData: BuyCryptoParamsForm {}

        popupParent: root.popupParent

        fnGetLoginType: root.rootStore.getLoginType
        transactionStore: root.transactionStore
        walletCollectiblesStore: root.walletCollectiblesStore
        transactionStoreNew: root.transactionStoreNew
        networksStore: root.networksStore
        networkConnectionStore: root.networkConnectionStore

        // for ens flows
        ensRegisteredAddress: root.ensUsernamesStore.getEnsRegisteredAddress()
        myPublicKey: root.contactsStore.myPublicKey
        getStatusTokenKey: function() {
            return root.ensUsernamesStore.getStatusTokenKey()
        }

        // for sticker flows
        stickersMarketAddress: root.rootChatStore.stickersStore.getStickersMarketAddress()
        stickersNetworkId: root.rootChatStore.appNetworkId

        simpleSendEnabled: root.featureFlagsStore.simpleSendEnabled
        buyEnabled: root.featureFlagsStore.buyEnabled

        // for simple send
        walletAccountsModel: root.walletRootStore.accounts
        filteredFlatNetworksModel: root.networksStore.activeNetworks
        flatNetworksModel: root.networksStore.allNetworks
        areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled
        groupedAccountAssetsModel: root.walletAssetsStore.groupedAccountAssetsModel
        plainTokensBySymbolModel: root.tokensStore.plainTokensBySymbolModel
        showCommunityAssetsInSend: root.tokensStore.showCommunityAssetsInSend
        collectiblesBySymbolModel: root.walletRootStore.collectiblesStore.jointCollectiblesBySymbolModel
        savedAddressesModel: root.walletRootStore.savedAddresses
        recentRecipientsModel: root.transactionStore.tempActivityController1Model

        isDetailedCollectibleLoading: root.walletCollectiblesStore.isDetailedCollectibleLoading
        detailedCollectible: root.walletCollectiblesStore.detailedCollectible

        currentCurrency: root.currencyStore.currentCurrency
        fnFormatCurrencyAmount: root.currencyStore.formatCurrencyAmount
        fnFormatCurrencyAmountFromBigInt: root.currencyStore.formatCurrencyAmountFromBigInt

        fnResolveENS: function(ensName, uuid) {
            root.rootStore.resolveENS(ensName, uuid)
        }

        fnGetEnsnameResolverAddress: function(ensName) {
            return  root.ensUsernamesStore.getEnsnameResolverAddress(ensName)
        }

        fnGetDetailedCollectible: function(chainId, contractAddress, tokenId) {
            root.walletCollectiblesStore.getDetailedCollectible(chainId, contractAddress, tokenId)
        }

        fnResetDetailedCollectible: function() {
            root.walletCollectiblesStore.resetDetailedCollectible()
        }

        fnGetOpenSeaUrl: function(networkShortName) {

            return root.walletRootStore.getOpenSeaUrl(networkShortName)
        }

        onLaunchBuyFlowRequested: {
            buyFormData.selectedWalletAddress = accountAddress
            buyFormData.selectedNetworkChainId = chainId
            buyFormData.selectedTokenKey = tokenKey
            Global.openBuyCryptoModalRequested(buyFormData)
        }

        Component.onCompleted: {
            // It's requested from many nested places, so as a workaround we use
            // Global to shorten the path via global signal.
            Global.sendToRecipientRequested.connect(sendToRecipient)
            root.rootStore.ensNameResolved.connect(ensNameResolved)
        }
    }

    readonly property StatusGifPopupHandler statusGifPopupHandler: StatusGifPopupHandler {
        gifStore: sharedRootStore.gifStore
        gifUnfurlingEnabled: sharedRootStore.gifUnfurlingEnabled
    }

    readonly property ThirdpartyServicesPopupHandler thirdpartyServicesPopupHandler: ThirdpartyServicesPopupHandler {
        popupParent: root.popupParent
        thirdPartyServicesEnabled: root.privacyStore.thirdpartyServicesEnabled

        onToggleThirdpartyServicesEnabledRequested: {
            root.privacyStore.toggleThirdpartyServicesEnabledRequested()
            Backpressure.debounce(root, 200, () => { SystemUtils.restartApplication() })()
        }
        onOpenDiscussPageRequested: Global.requestOpenLink(Constants.statusDiscussPageUrl)
        onOpenThirdpartyServicesArticleRequested: Global.requestOpenLink(Constants.statusThirdpartyServicesArticle)
    }

    readonly property Component enableMessageBackupPopupComponent: Component {
        EnableMessageBackupPopup {
            visible: true
            destroyOnClose: true
            onClosed: appMainLocalSettings.enableMessageBackupPopupSeen = true
            onAccepted: appMain.devicesStore.setMessagesBackupEnabled(true)
        }
    }

    function maybeDisplayEnableMessageBackupPopup() {
        if (!appMainLocalSettings.enableMessageBackupPopupSeen && !appMain.devicesStore.messagesBackupEnabled) {
            enableMessageBackupPopupComponent.createObject(appMain).open()
            return true
        }
        return false
    }

    readonly property EnableBiometricsPopupHandler enableBiometricsPopupHandler: EnableBiometricsPopupHandler {
        popupParent: root.popupParent
        privacyStore: root.privacyStore
        keychain: root.keychain
    }
}

import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
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


import MobileUI

// Public API for this object are ONLY `stores` + the main `popupParent`
QtObject {
    id: root

    required property Item popupParent

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

    required property ProfileStores.AboutStore aboutStore
    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property ProfileStores.PrivacyStore privacyStore

    required property Keychain keychain


    readonly property SwapModalHandler swapModalHandler: SwapModalHandler {


        function launchSwap() {
            if (root.walletRootStore.areTestNetworksEnabled) {
                Global.openInfoPopup(qsTr("Info"), qsTr("Swap is not available in the testnet mode."))
                return
            }

            const data = {
                selectedAccountAddress: SQUtils.ModelUtils.get(root.walletRootStore.nonWatchAccounts, 0, "address"),
                selectedNetworkChainId: SQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "layer", 1, "chainId")
            }

            openSendModal(data)
        }

        function launchSwapSpecific(data) {
            if (root.walletRootStore.areTestNetworksEnabled) {
                Global.openInfoPopup(qsTr("Info"), qsTr("Swap is not available in the testnet mode."))
                return
            }

            openSendModal(data)
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
        ensRegisteredAddress: root.ensUsernamesStore.ensRegisteredAddress
        myPublicKey: root.contactsStore.myPublicKey
        getStatusTokenGroupKey: function() {
            return root.ensUsernamesStore.getStatusTokenGroupKey()
        }

        // for sticker flows
        stickersMarketAddress: root.rootChatStore.stickersStore.getStickersMarketAddress()
        stickersNetworkId: root.rootChatStore.appNetworkId

        buyEnabled: root.featureFlagsStore.buyEnabled

        // for simple send
        walletAccountsModel: root.walletRootStore.accounts
        searchResultModel: root.tokensStore.searchResultModel
        filteredFlatNetworksModel: root.networksStore.activeNetworks
        flatNetworksModel: root.networksStore.allNetworks
        areTestNetworksEnabled: root.networksStore.areTestNetworksEnabled
        groupedAccountAssetsModel: root.walletAssetsStore.groupedAccountAssetsModel
        tokenGroupsModel: root.tokensStore.tokenGroupsModel
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

        onLaunchBuyFlowRequested: function (accountAddress, chainId, groupKey) {
            buyFormData.selectedWalletAddress = accountAddress
            buyFormData.selectedNetworkChainId = chainId
            buyFormData.selectedTokenGroupKey = groupKey
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
        thirdpartyServicesEnabled: root.privacyStore.thirdpartyServicesEnabled

        onEnableThirdpartyServicesRequested: root.thirdpartyServicesPopupHandler.openPopup()
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
            enableMessageBackupPopupComponent.createObject(popupParent).open()
            return true
        }
        return false
    }

    readonly property Component enablePushNotificationsPopupComponent: Component {
        EnablePushNotificationsPopup {
            id: enablePushNotificationsPopup
            destroyOnClose: true
            hasPermission: PushNotifications.status === PushNotifications.Granted

            onClosed: {
                appMainLocalSettings.enablePushNotificationsFreshInstallSeen = true
                appMainLocalSettings.enablePushNotificationsDontAskAgain = enablePushNotificationsPopup.dontAskAgain
                appMainLocalSettings.enablePushNotificationsLastShownVersion = currentMinorVersion()
            }

            onContinueRequested: {
                PushNotifications.request()

                enablePushNotificationsPopup.loading = true
            }

            onOpenSettingsRequested: {
                PushNotifications.openSettings()
                enablePushNotificationsPopup.close()
            }


            Connections {
                target: PushNotifications

                function onStatusChanged() {
                    enablePushNotificationsPopup.loading = false
                    enablePushNotificationsPopup.hasPermission = PushNotifications.status === PushNotifications.Granted

                    if (PushNotifications.status === PushNotifications.Granted) {
                        Global.displayToastMessage(
                            qsTr("Push notifications enabled"),
                            "",
                            "checkmark-circle",
                            false,
                            Constants.ephemeralNotificationType.success,
                            ""
                        )
                        PushNotifications.requestToken()
                        enablePushNotificationsPopup.close()
                        return
                    }
                }
            }
        }
    }

    function currentMinorVersion(): string {
        const match = /^v?(\d+)\.(\d+)/.exec(root.aboutStore.getCurrentVersion() || "")
        if (!match) {
            return ""
        }
        return "%1.%2".arg(match[1]).arg(match[2])
    }

    function isAtLeastMinorVersion(version: string, minimum: string): bool {
        const versionParts = version.split(".").map(Number)
        const minimumParts = minimum.split(".").map(Number)
        if (versionParts.length < 2 || minimumParts.length < 2 ||
                isNaN(versionParts[0]) || isNaN(versionParts[1]) ||
                isNaN(minimumParts[0]) || isNaN(minimumParts[1])) {
            return false
        }

        return versionParts[0] > minimumParts[0] ||
                (versionParts[0] === minimumParts[0] && versionParts[1] >= minimumParts[1])
    }

    function showEnablePushNotificationsPopup() {
        enablePushNotificationsPopupComponent.createObject(root.popupParent).open()
    }

    readonly property Connections pushNotificationsConnections: Connections {
        target: PushNotifications
        function onTokenChanged() {
            if (PushNotifications.token !== "" && SQUtils.Utils.isIOS) {
                appSettings.registerForCentralizedPushNotifications(PushNotifications.token)
            }
        }
    }

    readonly property Connections pushNotificationsStatusConnections: Connections {
        target: PushNotifications
        enabled: false
        function onStatusChanged() {
            if (PushNotifications.status !== PushNotifications.Granted) {
                showEnablePushNotificationsPopup()
            }

            Qt.callLater(() => {
                pushNotificationsStatusConnections.enabled = false
            })
        }
    }

    function maybeDisplayEnablePushNotificationsPopup() {
        if (!SQUtils.Utils.isMobile) {
            return
        }

        if (PushNotifications.status === PushNotifications.Granted) {
            PushNotifications.requestToken()
            return
        }

        const version = currentMinorVersion()
        const shouldDisplayAfterFreshInstall = !appMainLocalSettings.enablePushNotificationsFreshInstallSeen
        const shouldDisplayAfterMinorUpdate = !appSettings.notifSettingAllowNotifications &&
                !appMainLocalSettings.enablePushNotificationsDontAskAgain &&
                version !== "" &&
                isAtLeastMinorVersion(version, "2.38") &&
                appMainLocalSettings.enablePushNotificationsLastShownVersion !== version

        if (!shouldDisplayAfterFreshInstall && !shouldDisplayAfterMinorUpdate) {
            return
        }

        // Delay the popup display to avoid false negative when the status is unknown
        // If might take a while to get the status, so we delay the popup display
        // Platform specifics - iOS might take a while to get the status, so we delay the popup display
        // Platform specifics - Android won't return the status until the first request is made
        if (PushNotifications.status === PushNotifications.Unknown && SQUtils.Utils.isIOS) {
            pushNotificationsStatusConnections.enabled = true
            return
        }

        showEnablePushNotificationsPopup()
    }

    // Flat API — delegates to the nested handler instances above. Callers should
    // prefer these over `popupHandler.<nestedHandler>.<method>()` chains.
    function launchSwap() {
        swapModalHandler.launchSwap()
    }
    function launchSwapSpecific(data) {
        swapModalHandler.launchSwapSpecific(data)
    }

    function openSend() {
        sendModalHandler.openSend()
    }
    function transferOwnership(tokenId, senderAddress) {
        sendModalHandler.transferOwnership(tokenId, senderAddress)
    }
    function buyStickerPack(packId, price) {
        sendModalHandler.buyStickerPack(packId, price)
    }
    function sendToRecipient(address) {
        sendModalHandler.sendToRecipient(address)
    }
    function sendToken(senderAddress, groupKey, tokenType) {
        sendModalHandler.sendToken(senderAddress, groupKey, tokenType)
    }
    function connectUsername(ensName, ownerAddress) {
        sendModalHandler.connectUsername(ensName, ownerAddress)
    }
    function registerUsername(ensName, chainId) {
        sendModalHandler.registerUsername(ensName, chainId)
    }
    function releaseUsername(ensName, senderAddress, chainId) {
        sendModalHandler.releaseUsername(ensName, senderAddress, chainId)
    }
    function openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount) {
        sendModalHandler.openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount)
    }

    function openGifs(params, cbOnGifSelected, cbOnClose) {
        statusGifPopupHandler.openGifs(params, cbOnGifSelected, cbOnClose)
    }

    // Disambiguated names — both nested handlers expose `openPopup()`.
    function openThirdpartyServicesPopup() {
        thirdpartyServicesPopupHandler.openPopup()
    }
    function openEnableBiometricsPopup() {
        enableBiometricsPopupHandler.openPopup()
    }

    readonly property EnableBiometricsPopupHandler enableBiometricsPopupHandler: EnableBiometricsPopupHandler {
        popupParent: root.popupParent
        privacyStore: root.privacyStore
        keychain: root.keychain
    }
}

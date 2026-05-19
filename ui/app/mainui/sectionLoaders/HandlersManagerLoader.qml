import QtQml
import QtQuick

import StatusQ
import StatusQ.Core

import shared.stores as SharedStores
import shared.stores.send as SharedSendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Profile.stores as ProfileStores

Loader {
    id: root

    required property Item popupParent

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property AppStores.ContactsStore contactsStore

    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedSendStores.TransactionStore transactionStore

    required property var/*TODO: Apply strong typing once it's no longer a singleton*/ walletRootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property WalletStores.CollectiblesStore walletCollectiblesStore
    required property WalletStores.TransactionStoreNew transactionStoreNew
    required property WalletStores.TokensStore tokensStore
    required property ProfileStores.NotificationsStore notificationsStore
    
    required property ChatStores.RootStore rootChatStore

    required property ProfileStores.AboutStore aboutStore
    required property ProfileStores.EnsUsernamesStore ensUsernamesStore
    required property ProfileStores.PrivacyStore privacyStore

    required property Keychain keychain

    asynchronous: true
    active: false // loaded on demand by section loaders, never active by default

    QtObject {
        id: d

        property var pending: []
        property bool sourceSet: false

        function flushPending() {
            const calls = pending
            pending = []
            for (let i = 0; i < calls.length; ++i)
                calls[i]()
        }
    }

    function loadSection() {
        if (!root.active)
            return
        if (d.sourceSet)
            return
        d.sourceSet = true
        setSource(QmlCompiler.handlersManagerUrl, {
            popupParent:            Qt.binding(() => root.popupParent),
            rootStore:              Qt.binding(() => root.rootStore),
            featureFlagsStore:      Qt.binding(() => root.featureFlagsStore),
            contactsStore:          Qt.binding(() => root.contactsStore),
            sharedRootStore:        Qt.binding(() => root.sharedRootStore),
            currencyStore:          Qt.binding(() => root.currencyStore),
            networksStore:          Qt.binding(() => root.networksStore),
            networkConnectionStore: Qt.binding(() => root.networkConnectionStore),
            transactionStore:       Qt.binding(() => root.transactionStore),
            walletRootStore:        Qt.binding(() => root.walletRootStore),
            walletAssetsStore:      Qt.binding(() => root.walletAssetsStore),
            walletCollectiblesStore:Qt.binding(() => root.walletCollectiblesStore),
            transactionStoreNew:    Qt.binding(() => root.transactionStoreNew),
            tokensStore:            Qt.binding(() => root.tokensStore),
            rootChatStore:          Qt.binding(() => root.rootChatStore),
            aboutStore:             Qt.binding(() => root.aboutStore),
            ensUsernamesStore:      Qt.binding(() => root.ensUsernamesStore),
            privacyStore:           Qt.binding(() => root.privacyStore),
            keychain:               Qt.binding(() => root.keychain),
            notificationsStore:     Qt.binding(() => root.notificationsStore)
        })
    }

    // Triggers HandlersManager.qml to load (idempotent), then either runs `callable`
    // immediately (if HandlersManager is loaded) or queues it to run when async
    // load completes. Callers pass a closure that performs the actual call, e.g.
    //     invoke(() => root.item.swapModalHandler.launchSwap())
    // This keeps the call refactor-safe (no string method names) and preserves
    // argument types via JS lexical capture.
    function invoke(callable) {
        if (!!root.item) {
            callable()
            return
        }
        if (root.active == false) {
            root.active = true
        }
        d.pending.push(callable)
        loadSection()
    }

    // Top-level forwarders mirroring HandlersManager.qml's public functions.
    // Note: maybeDisplayEnableMessageBackupPopup() returns bool on HandlersManager;
    // the forwarder is fire-and-forget (no return value), since invoke() may queue.
    function maybeDisplayEnableMessageBackupPopup() {
        invoke(() => root.item.maybeDisplayEnableMessageBackupPopup())
    }
    function showEnablePushNotificationsPopup() {
        invoke(() => root.item.showEnablePushNotificationsPopup())
    }
    function maybeDisplayEnablePushNotificationsPopup() {
        invoke(() => root.item.maybeDisplayEnablePushNotificationsPopup())
    }

    // Flat method forwarders — mirror HandlersManager.qml's flat API, each routed
    // through invoke() so calls before the loader is ready get queued and the
    // lazy loader auto-loads on first call (active: false default).
    function launchSwap() {
        invoke(() => root.item.launchSwap())
    }
    function launchSwapSpecific(data) {
        invoke(() => root.item.launchSwapSpecific(data))
    }
    function openSend() {
        invoke(() => root.item.openSend())
    }
    function transferOwnership(tokenId, senderAddress) {
        invoke(() => root.item.transferOwnership(tokenId, senderAddress))
    }
    function buyStickerPack(packId, price) {
        invoke(() => root.item.buyStickerPack(packId, price))
    }
    function sendToRecipient(address) {
        invoke(() => root.item.sendToRecipient(address))
    }
    function sendToken(senderAddress, groupKey, tokenType) {
        invoke(() => root.item.sendToken(senderAddress, groupKey, tokenType))
    }
    function connectUsername(ensName, ownerAddress) {
        invoke(() => root.item.connectUsername(ensName, ownerAddress))
    }
    function registerUsername(ensName, chainId) {
        invoke(() => root.item.registerUsername(ensName, chainId))
    }
    function releaseUsername(ensName, senderAddress, chainId) {
        invoke(() => root.item.releaseUsername(ensName, senderAddress, chainId))
    }
    function openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount) {
        invoke(() => root.item.openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount))
    }
    function openGifs(params, cbOnGifSelected, cbOnClose) {
        invoke(() => root.item.openGifs(params, cbOnGifSelected, cbOnClose))
    }
    function openThirdpartyServicesPopup() {
        invoke(() => root.item.openThirdpartyServicesPopup())
    }
    function openEnableBiometricsPopup() {
        invoke(() => root.item.openEnableBiometricsPopup())
    }

    onLoaded: d.flushPending()
    onActiveChanged: loadSection()

    Component.onCompleted: {
        QmlCompiler.precompile(QmlCompiler.handlersManagerUrl)
        loadSection()
    }
}

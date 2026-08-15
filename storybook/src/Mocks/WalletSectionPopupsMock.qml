import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

/*!
    Everything the wallet section needs to actually open a popup, in one place.

    Two mechanisms are involved and only one of them is `popupHandler`:

    - send and swap travel through the real `HandlersManagerLoader`, so this
      component supplies the twenty-odd stores it requires — production ones
      wherever the section already reaches them (the wallet `RootStore`
      singleton owns the assets/collectibles/tokens stores), storybook stubs for
      the chat and profile corners the wallet never touches;
    - receive and buy are `Global` signals that `AppMain` / `Popups.qml` answer
      in the app. Rather than standing up all of `Popups.qml`, the two modals are
      instantiated here against the same stores.

    `popupHandler` is the loader to hand to `WalletLoader`.
*/
Item {
    id: root

    required property Item popupParent

    required property AppStores.RootStore rootStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property AppStores.ContactsStore contactsStore

    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SendStores.TransactionStore transactionStore

    readonly property alias popupHandler: handlersManagerLoader

    visible: false

    SharedStores.CurrenciesStore { id: currencyStoreMock }
    ChatStores.RootStore { id: chatRootStoreMock }
    ProfileStores.AboutStore { id: aboutStoreMock }
    ProfileStores.DevicesStore { id: devicesStoreMock }
    ProfileStores.EnsUsernamesStore { id: ensUsernamesStoreMock }
    ProfileStores.NotificationsStore { id: notificationsStoreMock }
    ProfileStores.PrivacyStore { id: privacyStoreMock }
    WalletStores.TransactionStoreNew { id: transactionStoreNewMock }
    WalletStores.BuyCryptoStore { id: buyCryptoStoreMock }
    Keychain { id: keychainMock }

    HandlersManagerLoader {
        id: handlersManagerLoader

        popupParent: root.popupParent

        rootStore: root.rootStore
        featureFlagsStore: root.featureFlagsStore
        contactsStore: root.contactsStore

        sharedRootStore: root.sharedRootStore
        currencyStore: currencyStoreMock
        networksStore: root.networksStore
        networkConnectionStore: root.networkConnectionStore
        transactionStore: root.transactionStore

        // The wallet RootStore singleton owns these; a second set would filter
        // and paginate independently of the section on screen.
        walletRootStore: WalletStores.RootStore
        walletAssetsStore: WalletStores.RootStore.walletAssetsStore
        walletCollectiblesStore: WalletStores.RootStore.collectiblesStore
        tokensStore: WalletStores.RootStore.tokensStore
        transactionStoreNew: transactionStoreNewMock

        rootChatStore: chatRootStoreMock

        aboutStore: aboutStoreMock
        devicesStore: devicesStoreMock
        ensUsernamesStore: ensUsernamesStoreMock
        notificationsStore: notificationsStoreMock
        privacyStore: privacyStoreMock

        keychain: keychainMock
    }

    // --- Global-driven popups, mirroring AppMain / Popups.qml

    Connections {
        target: Global

        function onOpenShowQRPopup(params) {
            receiveModal.open(params ?? ({}))
        }

        function onOpenBuyCryptoModalRequested(formDataParams) {
            buyCryptoModal.open(formDataParams)
        }
    }

    Loader {
        id: receiveModal

        active: false

        property var params: ({})

        function open(newParams) {
            receiveModal.params = newParams
            receiveModal.active = true
        }

        onLoaded: {
            item.switchingAccounsEnabled = receiveModal.params.switchingAccounsEnabled ?? true
            item.hasFloatingButtons = receiveModal.params.hasFloatingButtons ?? true
            item.open()
        }

        sourceComponent: ReceiveModal {
            parent: root.popupParent

            accounts: WalletStores.RootStore.accounts
            selectedAccount: SQUtils.ModelUtils.get(WalletStores.RootStore.accounts, 0)

            onUpdateSelectedAddress: address => root.transactionStore.setReceiverAccount(address)
            onClosed: receiveModal.active = false
        }
    }

    Loader {
        id: buyCryptoModal

        active: false

        property var formData: null

        // Owned here rather than by the modal: created for the open modal and
        // released when it closes, as Popups.qml does in the app
        property var tokenSelector: null

        function open(newFormData) {
            buyCryptoModal.formData = newFormData
            buyCryptoModal.tokenSelector = WalletStores.RootStore.tokensStore.createTokenSelectorModel(2)
            buyCryptoModal.active = true
        }

        function close() {
            buyCryptoModal.active = false
            if (buyCryptoModal.tokenSelector) {
                WalletStores.RootStore.tokensStore.releaseTokenSelectorModel(buyCryptoModal.tokenSelector.id)
                buyCryptoModal.tokenSelector = null
            }
        }

        onLoaded: item.open()

        sourceComponent: BuyCryptoModal {
            parent: root.popupParent

            buyCryptoInputParamsForm: buyCryptoModal.formData
            buyProvidersModel: buyCryptoStoreMock.providersModel
            isBuyProvidersModelLoading: buyCryptoStoreMock.areProvidersLoading
            formatCurrencyBalance: amount => currencyStoreMock.formatCurrencyAmount(
                                       amount, currencyStoreMock.currentCurrency)
            walletAccountsModel: WalletStores.RootStore.accounts
            tokenGroupsModel: WalletStores.RootStore.tokensStore.tokenGroupsModel
            groupedAccountAssetsModel: WalletStores.RootStore.walletAssetsStore.groupedAccountAssetsModel
            networksModel: root.networksStore.activeNetworks
            tokenSelectorModel: buyCryptoModal.tokenSelector.model

            Component.onCompleted: {
                fetchProviders.connect(buyCryptoStoreMock.fetchProviders)
                fetchProviderUrl.connect(buyCryptoStoreMock.fetchProviderUrl)
                buyCryptoStoreMock.providerUrlReady.connect(providerUrlReady)
            }

            onClosed: buyCryptoModal.close()
        }
    }
}

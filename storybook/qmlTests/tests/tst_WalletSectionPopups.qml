import QtQuick
import QtTest

import StatusQ.Core.Theme

import utils

import shared.popups.addaccount
import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.stores as WalletStores

import Mocks
import Models

// The wallet section's popups are reachable: send and swap through the real
// HandlersManagerLoader, receive and buy through the Global signals AppMain and
// Popups.qml answer in the app. All four are wired by WalletSectionPopupsMock.
Item {
    id: root

    width: 1000
    height: 700

    WalletSectionMock {
        id: walletMock

        accountCount: 3
        assetGroupCount: 20
        collectibleCount: 5
        savedAddressCount: 4
        communityCount: 1
    }

    AppStores.RootStore { id: appRootStore }
    AppStores.ContactsStore { id: contactsStore }
    AppStores.FeatureFlagsStore {
        id: featureFlagsStore
        swapEnabled: true
        buyEnabled: true
    }
    SharedStores.RootStore { id: sharedRootStore }
    SharedStores.NetworkConnectionStore { id: networkConnectionStore }
    SharedStores.NetworksStore { id: networksStore }
    WalletSectionTransactionStoreMock { id: transactionStore }

    Item {
        id: popupParent
        anchors.fill: parent
    }

    Component {
        id: buyFormComponent
        BuyCryptoParamsForm {}
    }

    Component {
        id: addAccountPopupComponent
        AddAccountPopup {
            store.addAccountModule: walletSection.addAccountModule
            store.emojiPopup: null
        }
    }

    WalletSectionPopupsMock {
        id: popupsMock

        popupParent: popupParent

        rootStore: appRootStore
        featureFlagsStore: featureFlagsStore
        contactsStore: contactsStore
        sharedRootStore: sharedRootStore
        networksStore: networksStore
        networkConnectionStore: networkConnectionStore
        transactionStore: transactionStore
    }

    TestCase {
        name: "WalletSectionPopups"
        when: windowShown

        // Popups reparent their content into the window overlay, outside `root`
        function popupChild(objectName) {
            return findChild(root.Window.window.contentItem, objectName)
        }

        function initTestCase() {
            WalletStores.RootStore.palette = Theme.palette
        }

        function init() {
            walletMock.install()
        }

        function cleanup() {
            // Popups outlive the test that opened them; they are created on
            // popupParent, so clearing its children takes them with it
            for (const child of popupParent.data)
                child.destroy()
            walletMock.uninstall()
        }

        function test_activeNetworksCoverEverySupportedMainnet() {
            // The generated profile spreads balances over the active chains; a
            // networks mock with two of them makes the whole section look narrow.
            verify(networksStore.activeNetworks.count >= 4)
            for (let i = 0; i < networksStore.activeNetworks.count; ++i)
                compare(networksStore.activeNetworks.get(i).isTest, false)
        }

        function test_sendModalOpens() {
            popupsMock.popupHandler.openSend()
            tryVerify(() => !!popupChild("accountSelector"))
        }

        function test_swapModalOpens() {
            popupsMock.popupHandler.launchSwap()
            tryVerify(() => !!popupChild("swapModal"))
        }

        function test_receiveModalOpens() {
            Global.openShowQRPopup({})
            tryVerify(() => !!popupChild("receiveModal"))
        }

        function test_buyCryptoModalOpens() {
            Global.openBuyCryptoModalRequested(buyFormComponent.createObject(root))
            tryVerify(() => !!popupChild("providersList"))
        }

        // Add-account does not go through popupHandler: WalletLayout listens for
        // walletSection.displayAddAccountPopup and builds the popup against
        // walletSection.addAccountModule.
        function test_addAccountPopupOpensOnItsMainState() {
            const popup = addAccountPopupComponent.createObject(popupParent)
            verify(!!popup)
            popup.open()
            tryVerify(() => !!popupChild("AddAccountPopup-OriginSelector"))
            verify(!!popupChild("AddAccountPopup-PrimaryButton"))
        }
    }
}

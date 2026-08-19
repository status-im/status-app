import QtQuick
import QtTest

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

import utils

import Mocks
import Models
import StorybookMocks

// The wallet's two detail views are behind async Loaders keyed on the stack
// index (issues/0002), which moves three behaviours off the plain-child version
// and onto the loader:
//
//  - the token to display is picked before anything to display it in exists;
//  - a navigation request can land while the loader is still incubating;
//  - the reset that used to hang off `visible` has to fire when the view is
//    unloaded, which is not a visibility change.
//
// Driven through the real section loader rather than a bare RightTabView: the
// view is not an exported type, and the loader is how the app reaches it.
Item {
    id: root

    width: 1000
    height: 700

    // Small profile on purpose: this suite is functional, not a bench.
    WalletSectionMock {
        id: walletMock
        accountCount: 2
        assetGroupCount: 8
        collectibleCount: 4
        communityCount: 1
        savedAddressCount: 2
        followingAddressCount: 2
    }

    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.FeatureFlagsStore { id: featureFlagsStoreMock }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    CommunityStores.CommunitiesStore { id: communitiesStoreMock }
    WalletSectionTransactionStoreMock { id: transactionStoreMock }

    Item {
        id: popupParent
        anchors.fill: parent
    }

    WalletSectionPopupsMock {
        id: popupsMock

        popupParent: popupParent

        rootStore: appRootStoreMock
        featureFlagsStore: featureFlagsStoreMock
        contactsStore: contactsStoreMock
        sharedRootStore: sharedRootStoreMock
        networksStore: networksStoreMock
        networkConnectionStore: networkConnectionStoreMock
        transactionStore: transactionStoreMock
    }

    Item {
        visible: false
        Loader { id: dappsServiceLoaderMock; active: false }
        Loader { id: emojiPopupLoaderMock; active: false }
    }

    Component {
        id: componentUnderTest

        WalletLoader {
            anchors.fill: parent

            active: true
            appMainVisible: true

            rootStore: appRootStoreMock
            contactsStore: contactsStoreMock
            featureFlagsStore: featureFlagsStoreMock
            sharedRootStore: sharedRootStoreMock
            networkConnectionStore: networkConnectionStoreMock
            networksStore: networksStoreMock
            communitiesStore: communitiesStoreMock
            transactionStore: transactionStoreMock

            popupHandler: popupsMock.popupHandler
            dappsServiceLoader: dappsServiceLoaderMock
            emojiPopupLoader: emojiPopupLoaderMock
        }
    }

    TestCase {
        id: testCase

        name: "WalletDetailViewDeferral"
        when: windowShown

        property Loader sectionLoader: null

        function initTestCase() {
            WalletStores.RootStore.palette = Theme.palette
            walletMock.install()
        }

        function cleanupTestCase() {
            walletMock.uninstall()
        }

        function init() {
            sectionLoader = createTemporaryObject(componentUnderTest, root)
            verify(!!sectionLoader)
            tryVerify(() => sectionLoader.status === Loader.Ready, 20000)
        }

        // Walks `data`, not `children`: the detail loaders live in a StackLayout
        // that RightTabBaseView reparents through a LayoutItemProxy, so they are
        // not visual children of the panel.
        function findByObjectName(object, objectName) {
            if (object.objectName === objectName)
                return object
            const kids = object.data ?? []
            for (let i = 0; i < kids.length; i++) {
                const found = findByObjectName(kids[i], objectName)
                if (found)
                    return found
            }
            return null
        }

        function rightTab() {
            const tab = sectionLoader.item.centerPanel.currentItem
            verify(!!tab, "the wallet section has no right tab view")
            return tab
        }

        function loaderNamed(objectName) {
            const loader = findByObjectName(rightTab(), objectName)
            verify(!!loader, "no %1 in the wallet's right tab view".arg(objectName))
            return loader
        }

        function assetsView() {
            const loader = loaderNamed("walletMainViewLoader")
            tryVerify(() => loader.status === Loader.Ready, 20000)
            return loader.item
        }

        function assetKeyAt(index) {
            const model = WalletStores.RootStore.walletAssetsStore.assetsModel
            return SQUtils.ModelUtils.get(model, index, "key")
        }

        // The point of the change: nothing of either detail view exists until
        // the stack is moved onto it.
        function test_detailViewsAreNotBuiltOnSectionLoad() {
            const assets = loaderNamed("assetDetailLoader")
            const collectibles = loaderNamed("collectibleDetailLoader")

            compare(assets.active, false)
            compare(assets.item, null)
            compare(collectibles.active, false)
            compare(collectibles.item, null)
            verify(assets.asynchronous, "the asset detail must incubate asynchronously")
            verify(collectibles.asynchronous,
                   "the collectible detail must incubate asynchronously")
        }

        // The token group is picked by the click handler, which runs while the
        // loader is still inactive; the view has to come up already showing it.
        function test_assetNavigationResolvesAfterIncubation() {
            const loader = loaderNamed("assetDetailLoader")
            const key = assetKeyAt(0)
            verify(!!key, "the mock profile produced no assets")

            assetsView().assetClicked(key)
            compare(loader.active, true)

            tryVerify(() => loader.status === Loader.Ready, 20000)
            verify(!!loader.item, "the asset detail loader is Ready with no item")
            compare(loader.item.tokenGroup.key, key)
        }

        // A second request landing while the first is still incubating must be
        // the one the view comes up with - the request is state, not a call.
        function test_assetNavigationDuringIncubationTakesTheLastRequest() {
            const loader = loaderNamed("assetDetailLoader")
            const view = assetsView()
            const firstKey = assetKeyAt(0)
            const secondKey = assetKeyAt(1)
            verify(!!firstKey && !!secondKey && firstKey !== secondKey,
                   "the mock profile needs two distinct assets for this test")

            view.assetClicked(firstKey)
            compare(loader.status, Loader.Loading,
                    "the asset detail was expected to still be incubating")
            view.assetClicked(secondKey)

            tryVerify(() => loader.status === Loader.Ready, 20000)
            compare(loader.item.tokenGroup.key, secondKey)
        }

        // Navigating away used to be a visibility change; it is now an unload,
        // and the same store reset has to happen.
        function test_leavingTheAssetDetailResetsTheViewedHolding() {
            const loader = loaderNamed("assetDetailLoader")

            assetsView().assetClicked(assetKeyAt(0))
            tryVerify(() => loader.status === Loader.Ready, 20000)
            verify(!!WalletStores.RootStore.currentViewedHoldingTokenGroupKey,
                   "opening the asset detail must set the currently viewed holding")

            // The chrome's back button, which is how the user leaves.
            sectionLoader.item.handleBackButtonClicked()

            compare(loader.active, false)
            compare(loader.item, null, "the asset detail must be unloaded, not hidden")
            compare(WalletStores.RootStore.currentViewedHoldingTokenGroupKey, "",
                    "unloading the asset detail must reset the currently viewed holding")
            compare(WalletStores.RootStore.currentViewedHoldingType, Constants.TokenType.ERC20)
        }

        function test_leavingTheCollectibleDetailResetsTheViewedHolding() {
            const loader = loaderNamed("collectibleDetailLoader")

            WalletStores.RootStore.setCurrentViewedHolding(
                        "uid", Constants.TokenType.ERC721, "")
            // Drives the stack directly: realising a collectible cell needs the
            // grid's own async chain, and what is under test is the loader.
            rightTab().content.currentIndex = 1
            compare(loader.active, true)
            tryVerify(() => loader.status === Loader.Ready, 20000)

            sectionLoader.item.handleBackButtonClicked()

            compare(loader.active, false)
            compare(loader.item, null, "the collectible detail must be unloaded, not hidden")
            compare(WalletStores.RootStore.currentViewedHoldingTokenGroupKey, "",
                    "unloading the collectible detail must reset the currently viewed holding")
            compare(WalletStores.RootStore.currentViewedHoldingType, Constants.TokenType.ERC721)
        }
    }
}

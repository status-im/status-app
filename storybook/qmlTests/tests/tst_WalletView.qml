import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Wallet.stores as WalletStores
import shared.stores as SharedStores

import "../../../ui/app/AppLayouts/Profile/views" as ProfileViews
import "../../../ui/app/AppLayouts/Profile/stores" as ProfileStores

Item {
    id: root

    width: 800
    height: 700

    ProfileStores.WalletStore {
        id: walletStoreMock

        palette: Theme.palette
        walletModule: QtObject {
            property bool hasPairedDevices: false
            property bool autoApplyKeypairMigrations: true
            property var accountsModule: QtObject {
                property var keyPairModel: ListModel {}
                property var accounts: ListModel {}
            }
        }
    }

    Component {
        id: viewComponent

        ProfileViews.WalletView {
            anchors.fill: parent
            contentWidth: 560
            sectionTitle: "Wallet"

            thirdpartyServicesEnabled: false
            walletStore: walletStoreMock
            tokensStore: WalletStores.TokensStore {}
            assetsStore: WalletStores.WalletAssetsStore {}
            collectiblesStore: WalletStores.CollectiblesStore {}
            networksStore: SharedStores.NetworksStore {}
        }
    }

    TestCase {
        name: "WalletView"
        when: windowShown

        function findStack(item) {
            for (let i = 0; i < item.children.length; ++i) {
                const child = item.children[i]
                if (child instanceof StackLayout)
                    return child
                const found = findStack(child)
                if (found)
                    return found
            }
            return null
        }

        function createView() {
            const view = createTemporaryObject(viewComponent, root)
            verify(!!view)
            const flickable = findChild(view, "settingsContentBaseScrollView").flickable
            tryVerify(() => flickable.height > 0 && flickable.contentHeight > 0)
            return { view, flickable, stack: findStack(view) }
        }

        function isInViewport(item, flickable) {
            const top = item.mapToItem(flickable, 0, 0).y
            return top >= 0 && top + item.height <= flickable.height
        }

        // Issue 23047: the e2e helper kept adding to contentY while the page was
        // still building, and the main page ended up scrolled out of sight.
        function test_scrollStepsKeepTheMainPageInView() {
            const { view, flickable, stack } = createView()
            const networksItem = findChild(view, "networksItem")
            verify(!!networksItem)
            // A hidden page is taller than the viewport, as on small windows.
            verify(stack.children[view.editNetworksViewIndex].implicitHeight > flickable.height)

            for (let i = 0; i < 20; ++i)
                flickable.contentY += Math.max(48, Math.floor(flickable.height * 0.6))

            verify(isInViewport(networksItem, flickable),
                   "contentY %1, contentHeight %2".arg(flickable.contentY).arg(flickable.contentHeight))
        }

        function test_aPageTallerThanTheViewportScrollsToItsEnd() {
            const { view, flickable, stack } = createView()
            const page = stack.children[view.editNetworksViewIndex]
            verify(page.implicitHeight > flickable.height)

            stack.currentIndex = view.editNetworksViewIndex

            tryVerify(() => flickable.contentHeight >= page.implicitHeight)
        }

        function test_aFillingPageGetsTheWholeViewport() {
            const { view, flickable, stack } = createView()
            const page = stack.children[view.networksViewIndex]

            stack.currentIndex = view.networksViewIndex

            tryVerify(() => page.height >= view.availableHeight)
        }
    }
}

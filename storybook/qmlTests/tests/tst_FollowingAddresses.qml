import QtQuick
import QtTest

import AppLayouts.Wallet.views
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores as AppLayoutStores
import shared.stores as SharedStores

Item {
    id: root
    width: 800
    height: 600

    ListModel {
        id: followingModel
    }

    Component {
        id: harnessComponent

        Item {
            width: 800
            height: 600

            property alias view: view
            property alias refreshSpy: refreshSpy

            SignalSpy {
                id: refreshSpy
                target: view
                signalName: "refreshRequested"
            }

            FollowingAddresses {
                id: view
                anchors.fill: parent
                contactsStore: AppLayoutStores.ContactsStore {}
                networkConnectionStore: SharedStores.NetworkConnectionStore {}
                networksStore: SharedStores.NetworksStore {}
                followingAddressesModel: followingModel
                totalFollowingCount: 0
                rootStore: WalletStores.RootStore
                selectedAddress: "0x1111111111111111111111111111111111111111"
            }
        }
    }

    TestCase {
        name: "FollowingAddresses"
        when: windowShown

        function createHarness() {
            const harness = createTemporaryObject(harnessComponent, root)
            verify(harness.refreshSpy.count >= 1)
            harness.view.followingAddressesUpdated()
            harness.refreshSpy.clear()
            return harness
        }

        function test_emptyState_visibleWhenThereAreNoFollows() {
            const harness = createHarness()
            const emptyState = findChild(harness.view, "followingAddressesEmptyState")
            verify(emptyState)
            tryCompare(emptyState, "visible", true)

            harness.view.totalFollowingCount = 3
            tryCompare(emptyState, "visible", false)
        }

        function test_search_debouncesAndRequestsFirstPage() {
            const harness = createHarness()
            const search = findChild(harness.view, "followingAddressesSearchBox")
            verify(search)

            search.text = "vitalik"
            wait(400)

            compare(harness.refreshSpy.count, 1)
            compare(harness.refreshSpy.signalArguments[0][1], "vitalik")
            compare(harness.refreshSpy.signalArguments[0][2], harness.view.pageSize)
            compare(harness.refreshSpy.signalArguments[0][3], 0)
            compare(harness.view.showPagination, false)
        }

        function test_pagination_requestsOffsetForSelectedPage() {
            const harness = createHarness()
            harness.view.totalFollowingCount = 25
            tryCompare(harness.view, "showPagination", true)

            harness.view.goToPage(3)

            compare(harness.refreshSpy.count, 1)
            compare(harness.refreshSpy.signalArguments[0][1], "")
            compare(harness.refreshSpy.signalArguments[0][2], 10)
            compare(harness.refreshSpy.signalArguments[0][3], 20)
        }
    }
}

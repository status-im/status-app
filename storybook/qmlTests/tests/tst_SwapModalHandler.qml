import QtQuick
import QtTest

import utils
import shared.stores
import AppLayouts.stores as AppLayoutStores
import mainui.Handlers

import Storybook
import Models
import Mocks

Item {
    id: root

    width: 800
    height: 700

    readonly property WalletAssetsStoreMock walletAssetsStore: WalletAssetsStoreMock {
        id: thisWalletAssetStore

        walletTokensStore: TokensStoreMock {
            tokenGroupsModel: TokenGroupsModel {}
            tokenGroupsForChainModel: TokenGroupsModel {
                skipInitialLoad: true
            }
            tokenGroupsForChainToModel: TokenGroupsModel {
                skipInitialLoad: true
            }
            searchResultModel: TokenGroupsModel {
                skipInitialLoad: true
                tokenGroupsForChainModel: thisWalletAssetStore.walletTokensStore.tokenGroupsForChainModel
            }
            _displayAssetsBelowBalanceThresholdDisplayAmountFunc: () => 0
        }
        readonly property var baseGroupedAccountAssetModel: GroupedAccountsAssetsModel {}
    }

    Component {
        id: handlerComponent

        SwapModalHandler {
            popupParent: root
            currencyStore: CurrenciesStore {}
            rootStore: AppLayoutStores.RootStore {}
            walletAssetsStore: root.walletAssetsStore
            networksStore: NetworksStore {}
            savedAddressesModel: ListModel {}
            recentRecipientsModel: ListModel {}
            swapEnabled: true
            routeOrderEnabled: true
        }
    }

    TestCase {
        name: "SwapModalHandler"
        when: windowShown

        // Every launch path (nav item, deep link, wallet views) funnels into
        // openSendModal, so the effective feature flag is enforced there.
        function test_swapDisabled_doesNotOpenModal() {
            const handler = createTemporaryObject(handlerComponent, root, { swapEnabled: false })
            verify(!!handler)

            let createdModal = null
            ignoreWarning("SwapModalHandler: swap is disabled by feature flag")
            handler.openSendModal({}, (modal) => { createdModal = modal })

            compare(createdModal, null)
            compare(findChild(root, "swapModal"), null)
        }

        function test_swapEnabled_opensModal() {
            const handler = createTemporaryObject(handlerComponent, root, { swapEnabled: true })
            verify(!!handler)

            let createdModal = null
            handler.openSendModal({}, (modal) => { createdModal = modal })

            verify(!!createdModal)
            compare(createdModal.objectName, "swapModal")
            compare(findChild(root, "swapModal"), createdModal)
            tryCompare(createdModal, "opened", true)

            // The modal destroys itself on close.
            createdModal.close()
            tryVerify(() => findChild(root, "swapModal") === null)
        }
    }
}

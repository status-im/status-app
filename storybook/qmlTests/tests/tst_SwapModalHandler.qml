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

        // The pay side lists the account's holdings, so the modal opens on the chain
        // where the account holds the pay token; held on no active chain, the pay side
        // is left for the user to pick. The receive side defaults to the chain's ETH.
        // Mock balances: account ..7240 holds USDC on mainnet and DAI only on Optimism
        // (inactive); account ..8881 holds USDC on no active chain and DAI on Arbitrum.
        function test_opensOnTheChainWhereThePayTokenIsHeld_data() {
            return [
                { tag: "USDC held on the requested chain", account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                  groupKey: undefined, chainId: 1, expectedChainId: 1, expectedFromGroupKey: Constants.usdcGroupKeyEvm },
                { tag: "USDC held on no active chain", account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                  groupKey: undefined, chainId: 1, expectedChainId: 1, expectedFromGroupKey: "" },
                { tag: "named token held on another chain", account: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                  groupKey: Constants.daiGroupKey, chainId: 1, expectedChainId: 42161, expectedFromGroupKey: Constants.daiGroupKey },
                { tag: "named token held on no active chain", account: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                  groupKey: Constants.daiGroupKey, chainId: 1, expectedChainId: 1, expectedFromGroupKey: "" },
            ]
        }

        function test_opensOnTheChainWhereThePayTokenIsHeld(data) {
            const handler = createTemporaryObject(handlerComponent, root, { swapEnabled: true })
            verify(!!handler)
            // the picker mock has no per-account balances: list nothing for an
            // account that, per the grouped balances above, holds no pay token
            root.walletAssetsStore.walletTokensStore.tokenSelectorEmptyAccounts = data.expectedFromGroupKey === "" ? [data.account] : []

            let createdModal = null
            handler.openSendModal({
                                      selectedAccountAddress: data.account,
                                      selectedNetworkChainId: data.chainId,
                                      defaultFromGroupKey: data.groupKey
                                  }, (modal) => { createdModal = modal })
            verify(!!createdModal)
            tryCompare(createdModal, "opened", true)

            const form = handler._d.swapInputParams
            tryCompare(form, "selectedAccountAddress", data.account)
            tryCompare(form, "selectedNetworkChainId", data.expectedChainId)
            compare(form.toNetworkChainId, data.expectedChainId, "a plain swap: the receive chain follows the pay chain")
            tryCompare(form, "fromGroupKey", data.expectedFromGroupKey)
            compare(form.toGroupKey, Constants.ethGroupKey, "ETH is received by default")

            createdModal.close()
            tryVerify(() => findChild(root, "swapModal") === null)
            root.walletAssetsStore.walletTokensStore.tokenSelectorEmptyAccounts = []
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

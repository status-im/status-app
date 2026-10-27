import QtQuick
import QtTest

import AppLayouts.Wallet.helpers

import Models
import Mocks

// A ChainTokenGroupsHolder holds its chain's token groups and exposes the
// chain's model, the same instance for every holder of the chain.
Item {
    id: root

    readonly property int chainA: 11155111
    readonly property int chainB: 11155420

    readonly property TokensStoreMock store: TokensStoreMock {
        tokenGroupsModel: TokenGroupsModel {}
    }

    Component {
        id: holderComponent

        ChainTokenGroupsHolder {
            property var seenModels: []

            tokensStore: root.store
            chainId: root.chainA
            onModelChanged: seenModels = seenModels.concat([model])
        }
    }

    TestCase {
        name: "ChainTokenGroupsHolder"

        function init() {
            root.store.chainTokenGroupsCalls = []
        }

        function test_holdersOfAChainShareItsModel() {
            const first = createTemporaryObject(holderComponent, root)
            const second = createTemporaryObject(holderComponent, root)
            verify(first.holding)
            verify(!!first.model)
            verify(first.model === second.model)
            verify(first.model === root.store.chainTokenGroupsModel(root.chainA))
            compare(root.store.chainTokenGroupsHolderCount(root.chainA), 2)

            second.chainId = root.chainB
            verify(second.model === root.store.chainTokenGroupsModel(root.chainB))
            verify(first.model !== second.model)
        }

        function test_aChainSwitchShowsNoNullInBetween() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.seenModels = []
            holder.chainId = root.chainB
            compare(holder.seenModels.length, 1)
            verify(holder.seenModels[0] === root.store.chainTokenGroupsModel(root.chainB))
            compare(root.store.chainTokenGroupsHolderCount(root.chainA), 0)
            compare(root.store.chainTokenGroupsHolderCount(root.chainB), 1)
        }

        function test_noChainOrInactiveHasNoModel() {
            const holder = createTemporaryObject(holderComponent, root, { chainId: 0 })
            verify(!holder.holding)
            compare(holder.model, null)

            holder.chainId = root.chainA
            verify(!!holder.model)

            holder.active = false
            verify(!holder.holding)
            compare(holder.model, null)
            compare(root.store.chainTokenGroupsHolderCount(root.chainA), 0)
        }

        function test_releasePassesTheKeysOfTheAcquire() {
            const holder = createTemporaryObject(holderComponent, root, { mandatoryKeys: "a$$b" })
            holder.mandatoryKeys = "c"
            holder.chainId = root.chainB
            holder.destroy()
            tryCompare(root.store, "chainTokenGroupsCalls", [
                ["acquire", root.chainA, "a$$b"],
                ["release", root.chainA, "a$$b"],
                ["acquire", root.chainB, "c"],
                ["release", root.chainB, "c"],
            ])
        }

        function test_loadingFollowsTheModel() {
            const holder = createTemporaryObject(holderComponent, root)
            verify(!holder.loading)
            holder.model.loading = true
            verify(holder.loading)
            holder.model.loading = false
        }
    }
}

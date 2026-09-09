import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

import AppLayouts.Wallet.stores

TokensStore {
    id: root

    property var tokenGroupsModel
    property var tokenGroupsForChainModel
    property var tokenGroupsForChainToModel
    property var searchResultModel
    property bool showCommunityAssetsInSend
    property bool displayAssetsBelowBalance
    property var _displayAssetsBelowBalanceThresholdDisplayAmountFunc: function() { return 0 }
    property double tokenListUpdatedAt

    // Terminal token-selector picker stub. The real producer (context property
    // walletSectionTokenSelector) is unavailable in storybook, so hand out
    // configurable TokenSelectorModelMock instances instead. Callers override
    // tokenSelectorStubData to seed the rows they need.
    property var tokenSelectorStubData: []
    property int _tokenSelectorIdCounter: 0
    readonly property Component _tokenSelectorModelMockComponent: Component { TokenSelectorModelMock {} }

    // The kind of every picker handed out, in order, so tests can assert which
    // pickers a consumer builds and when. Tests reset it to [] to scope a window.
    property var createdKinds: []

    function createTokenSelectorModel(kind) {
        root.createdKinds = root.createdKinds.concat([kind])
        // Mirror the producer's per-kind source: swap pay (1) uses the
        // source-chain groups, swap receive (3) the destination-chain groups,
        // send (0) / buy (2) the full groups. (The real producer additionally
        // swaps in the cross-chain groups while no chain filter is set — the
        // "All" chip; that path is covered by the Nim model tests.) If a caller
        // pre-seeded tokenSelectorStubData, use that static set instead.
        let props = {}
        if (!!root.tokenSelectorStubData && root.tokenSelectorStubData.length > 0)
            props = { sourceData: root.tokenSelectorStubData }
        else if (kind === 1)
            props = { sourceModel: root.tokenGroupsForChainModel }
        else if (kind === 3)
            props = { sourceModel: root.tokenGroupsForChainToModel }
        else
            props = { sourceModel: root.tokenGroupsModel }
        const model = _tokenSelectorModelMockComponent.createObject(root, props)
        return { model: model, id: root._tokenSelectorIdCounter++ }
    }

    function releaseTokenSelectorModel(id) {}

    property var swapUnsupportedChainIds: []
    function isChainSupportedForSwapViaLiFi(chainId) {
        return root.swapUnsupportedChainIds.indexOf(chainId) === -1
    }

    function getDisplayAssetsBelowBalanceThresholdDisplayAmount() {
        return _displayAssetsBelowBalanceThresholdDisplayAmountFunc()
    }

    property var builtChainIds: []

    // Like the real token service, each side's build touches only its own
    // catalog — the receive panel drives buildGroupsForChainTo itself.
    function buildGroupsForChain(chainId) {
        root.builtChainIds = root.builtChainIds.concat([chainId])
        root._buildGroupsInto(root.tokenGroupsForChainModel, chainId)
    }

    property var builtToChainIds: []

    function buildGroupsForChainTo(chainId) {
        root.builtToChainIds = root.builtToChainIds.concat([chainId])
        root._buildGroupsInto(root.tokenGroupsForChainToModel, chainId)
    }

    // The real store triggers the on-demand cross-chain catalog fetch here;
    // in storybook the mock models are static, so this only records the call.
    property int fetchAllChainsTokenGroupsCallCount: 0
    function fetchAllChainsTokenGroups(mandatoryKeys) {
        root.fetchAllChainsTokenGroupsCallCount++
    }

    function _buildGroupsInto(targetModel, chainId) {
        if (!root.tokenGroupsModel || chainId <= 0) {
            console.warn("buildGroupsForChain: invalid parameters", chainId)
            return
        }

        if (!targetModel) {
            console.warn("buildGroupsForChain: target model is not set")
            return
        }

        targetModel.clear()

        for (let i = 0; i < root.tokenGroupsModel.ModelCount.count; i++) {
            const group = ModelUtils.get(root.tokenGroupsModel, i)

            if (!group.tokens || group.tokens.ModelCount.count === 0) {
                continue
            }

            const tokensListModel = Qt.createQmlObject('import QtQuick; ListModel {}', root)
            for (let j = 0; j < group.tokens.ModelCount.count; j++) {
                const token = ModelUtils.get(group.tokens, j)
                if (token.chainId === chainId) {
                    tokensListModel.append({
                        key: token.key,
                        groupKey: token.groupKey,
                        crossChainId: token.crossChainId,
                        chainId: token.chainId,
                        address: token.address,
                        name: token.name,
                        symbol: token.symbol,
                        decimals: token.decimals,
                        image: token.image,
                        customToken: token.customToken,
                        communityId: token.communityId
                    })
                }
            }

            if (tokensListModel.count > 0) {
                targetModel.append({
                    key: group.key,
                    symbol: group.symbol,
                    name: group.name,
                    decimals: group.decimals,
                    logoUri: group.logoUri,
                    tokens: tokensListModel,
                    communityId: group.communityId || "",
                    marketDetails: group.marketDetails || {},
                    detailsLoading: group.detailsLoading || false,
                    marketDetailsLoading: group.marketDetailsLoading || false
                })
            }
        }
    }
}

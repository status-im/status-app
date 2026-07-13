import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

import AppLayouts.Wallet.stores

TokensStore {
    id: root

    property var tokenGroupsModel
    property var tokenGroupsForChainModel
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

    function createTokenSelectorModel(kind) {
        // Mirror the producer's per-kind source: swap (1) uses the chain-scoped
        // groups, send (0) / buy (2) use the full groups. If a caller pre-seeded
        // tokenSelectorStubData, use that static set instead.
        let props = {}
        if (!!root.tokenSelectorStubData && root.tokenSelectorStubData.length > 0)
            props = { sourceData: root.tokenSelectorStubData }
        else
            props = { sourceModel: (kind === 1 ? root.tokenGroupsForChainModel : root.tokenGroupsModel) }
        const model = _tokenSelectorModelMockComponent.createObject(root, props)
        return { model: model, id: root._tokenSelectorIdCounter++ }
    }

    function releaseTokenSelectorModel(id) {}

    function getDisplayAssetsBelowBalanceThresholdDisplayAmount() {
        return _displayAssetsBelowBalanceThresholdDisplayAmountFunc()
    }

    function buildGroupsForChain(chainId) {
        if (!root.tokenGroupsModel || chainId <= 0) {
            console.warn("buildGroupsForChain: invalid parameters", chainId)
            return
        }

        if (!root.tokenGroupsForChainModel) {
            console.warn("buildGroupsForChain: tokenGroupsForChainModel is not set")
            return
        }

        root.tokenGroupsForChainModel.clear()

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
                root.tokenGroupsForChainModel.append({
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

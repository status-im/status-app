import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

import AppLayouts.Wallet.stores

import Models

TokensStore {
    id: root

    property var tokenGroupsModel
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
    // accounts the handed-out pickers treat as holding nothing
    property var tokenSelectorEmptyAccounts: []
    property int _tokenSelectorIdCounter: 0
    readonly property Component _tokenSelectorModelMockComponent: Component { TokenSelectorModelMock {} }

    // The kind of every picker handed out, in order, so tests can assert which
    // pickers a consumer builds and when. Tests reset it to [] to scope a window.
    property var createdKinds: []

    function createTokenSelectorModel(kind) {
        root.createdKinds = root.createdKinds.concat([kind])
        // Mirror the producer's per-kind source: swap receive (3) uses the
        // shared model of the chain set by setTokenSelectorCatalogChain, owned
        // (0: send, swap pay) / buy (2) the full groups. (The real producer
        // additionally swaps in the cross-chain groups while no chain filter is
        // set — the "All" chip; that path is covered by the Nim model tests.) If
        // a caller pre-seeded tokenSelectorStubData, use that static set instead.
        let props = { ownedOnly: kind === 0, emptyAccounts: root.tokenSelectorEmptyAccounts }
        const stubbed = !!root.tokenSelectorStubData && root.tokenSelectorStubData.length > 0
        if (stubbed)
            props.sourceData = root.tokenSelectorStubData
        else if (kind !== 3)
            props.sourceModel = root.tokenGroupsModel
        const model = _tokenSelectorModelMockComponent.createObject(root, props)
        const id = root._tokenSelectorIdCounter++
        if (kind === 3 && !stubbed)
            root._catalogPickers[id] = { model: model, chainId: -1 }
        return { model: model, id: id }
    }

    function releaseTokenSelectorModel(id) {
        delete root._catalogPickers[id]
    }

    // swap receive pickers by id, with the chain each lists
    property var _catalogPickers: ({})

    function setTokenSelectorCatalogChain(id, chainId) {
        const picker = root._catalogPickers[id]
        if (!picker)
            return
        picker.chainId = chainId
        picker.model.sourceModel = root.chainTokenGroupsModel(chainId)
    }

    property var swapUnsupportedChainIds: []
    function isChainSupportedForSwap(chainId) {
        return root.swapUnsupportedChainIds.indexOf(chainId) === -1
    }

    function getDisplayAssetsBelowBalanceThresholdDisplayAmount() {
        return _displayAssetsBelowBalanceThresholdDisplayAmountFunc()
    }

    // every chain acquired, in order, so tests can assert which chains a
    // consumer holds and when; tests reset it to [] to scope a window
    property var acquiredChainIds: []
    // every acquire and release with the keys it passed, as [op, chainId, keys]
    property var chainTokenGroupsCalls: []

    // One model per chain, built on its first holder and kept, as the real one
    // is within the idle delay. The mock fills it at once, as if loaded.
    property var _chainModels: ({})
    readonly property Component _chainModelComponent: Component { TokenGroupsModel { skipInitialLoad: true } }

    function chainTokenGroupsModel(chainId) {
        return root._chainModels[chainId] ?? null
    }

    // Holder counts by resource, as the real token service keeps them. The
    // mock models are static, so holds only get counted.
    property var chainTokenGroupsHolders: ({})
    property int allTokenGroupsHolders: 0
    property int tokenListsHolders: 0

    function chainTokenGroupsHolderCount(chainId) {
        return root.chainTokenGroupsHolders[chainId] ?? 0
    }

    function _addChainTokenGroupsHolders(chainId, delta) {
        const holders = Object.assign({}, root.chainTokenGroupsHolders)
        holders[chainId] = (holders[chainId] ?? 0) + delta
        if (holders[chainId] < 0)
            console.warn("releaseChainTokenGroups: chain not held", chainId)
        root.chainTokenGroupsHolders = holders
    }

    function acquireChainTokenGroups(chainId, mandatoryKeys) {
        root.acquiredChainIds = root.acquiredChainIds.concat([chainId])
        root.chainTokenGroupsCalls = root.chainTokenGroupsCalls.concat([["acquire", chainId, mandatoryKeys ?? ""]])
        root._addChainTokenGroupsHolders(chainId, 1)
        if (!!root._chainModels[chainId])
            return
        const model = root._chainModelComponent.createObject(root)
        root._buildGroupsInto(model, chainId)
        root._chainModels[chainId] = model
        for (const id in root._catalogPickers) {
            const picker = root._catalogPickers[id]
            if (picker.chainId === chainId)
                picker.model.sourceModel = model
        }
    }

    function releaseChainTokenGroups(chainId, mandatoryKeys) {
        root.chainTokenGroupsCalls = root.chainTokenGroupsCalls.concat([["release", chainId, mandatoryKeys ?? ""]])
        root._addChainTokenGroupsHolders(chainId, -1)
    }

    function acquireAllTokenGroups() {
        root.allTokenGroupsHolders++
    }

    function releaseAllTokenGroups() {
        root.allTokenGroupsHolders--
    }

    function acquireTokenLists() {
        root.tokenListsHolders++
    }

    function releaseTokenLists() {
        root.tokenListsHolders--
    }
    // Tokens outside every model, keyed by token or group key, that the last-resort
    // lookup below can still resolve (the real store asks the backend's full list).
    property var allTokensByKey: ({})

    // The real store asks the backend for the price of an unpriced token or group;
    // the mock only reports the request.
    signal pricesForGroupRequested(string key)
    function ensurePricesForGroup(key) {
        root.pricesForGroupRequested(key)
    }

    function getTokenByKeyOrGroupKeyFromAllTokens(key) {
        if (!!root.allTokensByKey[key])
            return root.allTokensByKey[key]
        const count = !!root.tokenGroupsModel ? root.tokenGroupsModel.ModelCount.count : 0
        for (let i = 0; i < count; i++) {
            const group = ModelUtils.get(root.tokenGroupsModel, i)
            if (!group.tokens)
                continue
            for (let j = 0; j < group.tokens.ModelCount.count; j++) {
                const token = ModelUtils.get(group.tokens, j)
                if (token.key === key || token.groupKey === key)
                    return token
            }
        }
        return { key: "", groupKey: "", symbol: "", name: "", decimals: 0, chainId: 0 }
    }

    function _buildGroupsInto(targetModel, chainId) {
        if (!root.tokenGroupsModel || chainId <= 0) {
            console.warn("acquireChainTokenGroups: invalid parameters", chainId)
            return
        }

        if (!targetModel) {
            console.warn("acquireChainTokenGroups: target model is not set")
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

import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit

// Storybook/test stub for the Nim TokenSelectorModel. The real producer
// (context property walletSectionTokenSelector) is unavailable in storybook, so
// TokensStoreMock.createTokenSelectorModel hands out instances of this instead.
// Exposes the QML-facing contract the pickers consume: terminal roles per row,
// the writable per-modal params, the lazy read props, and the
// search/fetchMore/setSectionNames slots (reduced to plain state here).
//
// Rows come from either `sourceData` (a plain array, for pages/tests that want a
// fixed set) or `sourceModel` (a live token-groups model whose rows are mapped
// to terminal roles and kept in sync — mirrors the producer's owned/popular
// source).
ListModel {
    id: root

    // Per-modal params driven by the consuming panel via Binding.
    property int enabledChainId: -1
    property string accountAddress: ""
    property bool showZeroBalanceForDefaultTokens: false
    property bool showCommunityAssets: false

    // Lazy-source read props.
    property bool hasMoreItems: false
    property bool isLoadingMore: false
    property string searchString: ""

    // Static rows (each must carry the terminal roles). Ignored when sourceModel
    // is set.
    property var sourceData: []

    // Live token-groups source (e.g. tokenGroupsForChainModel / tokenGroupsModel);
    // its rows are mapped to terminal roles and rebuilt when it changes.
    property var sourceModel: null

    // Section titles are translated in QML and pushed down; recorded here so tests
    // can assert the panel pushed them (the real model keeps them internal and
    // surfaces them through the per-row sectionName role).
    property string ownedSectionName: ""
    property string popularSectionName: ""

    // Counted because the real model's search() also re-seeds the backend list,
    // so "was it called" is observable behaviour even for the empty keyword.
    property int searchCallCount: 0

    function search(keyword) {
        root.searchCallCount++
        root.searchString = keyword
    }
    function fetchMore() {}
    function setSectionNames(owned, popular) {
        root.ownedSectionName = owned
        root.popularSectionName = popular
    }

    // A large synthetic owned balance so mapped rows behave as owned tokens with
    // headroom for the preset amounts the swap tests exercise. The real
    // owned-balance join lives in the Nim producer; the model tests assert its
    // values. Here we only need a consistent non-zero balance so the panel's
    // valueValid / max / fiat wiring has something to compute against.
    property real syntheticBalance: 5000000000.0

    function _mapGroup(group) {
        let tokens = []
        let balances = []
        const price = (!!group.marketDetails && !!group.marketDetails.currencyPrice)
                      ? group.marketDetails.currencyPrice.amount : 0
        if (!!group.tokens) {
            for (let i = 0; i < group.tokens.ModelCount.count; i++) {
                const t = ModelUtils.get(group.tokens, i)
                tokens.push({ key: t.key, chainId: t.chainId })
                balances.push({
                    chainId: t.chainId,
                    iconUrl: "",
                    chainName: "",
                    balance: root.syntheticBalance,
                    rawBalance: "1000000000000000000000000000000"
                })
            }
        }
        return {
            key: group.key,
            name: group.name,
            symbol: group.symbol,
            logoUri: group.logoUri || "",
            decimals: group.decimals || 18,
            cryptoPrice: price,
            currentBalance: root.syntheticBalance,
            currencyBalance: root.syntheticBalance * price,
            sectionName: group.sectionName || "",
            balances: balances,
            tokens: tokens
        }
    }

    // Sync rows IN PLACE — replace existing rows (dataChanged), append new tail
    // rows (insert), drop the surplus (remove) — instead of clear()+append. The
    // real terminal model never resets, so neither does the stub: keys stay
    // present, so a selection bound by key survives a source change.
    function _syncRows(newRows) {
        const n = newRows.length
        for (let i = 0; i < n; i++) {
            if (i < count)
                set(i, newRows[i])
            else
                append(newRows[i])
        }
        if (count > n)
            remove(n, count - n)
    }

    function _reload() {
        let newRows = []
        if (!!sourceModel) {
            for (let i = 0; i < sourceModel.ModelCount.count; i++)
                newRows.push(_mapGroup(ModelUtils.get(sourceModel, i)))
        } else if (!!sourceData && sourceData.length > 0) {
            newRows = sourceData
        }
        _syncRows(newRows)
    }

    onSourceDataChanged: _reload()
    onSourceModelChanged: _reload()

    // Rebuild whenever the source's row count changes (e.g. buildGroupsForChain
    // clears + repopulates the chain-scoped groups). A bound property is reliably
    // reactive here (a Connections wrapped in a property on a ListModel is not).
    readonly property int _sourceCount: !!sourceModel ? sourceModel.count : 0
    on_SourceCountChanged: _reload()

    Component.onCompleted: _reload()
}

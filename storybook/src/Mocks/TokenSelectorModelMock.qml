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

    // Per-modal params driven by the consuming panel via Binding. The chain
    // filter is honoured like the real builder does: a group is listed while it
    // has a token on that chain, and its balances narrow to that chain.
    property int enabledChainId: -1
    onEnabledChainIdChanged: _reload()
    property string accountAddress: ""
    onAccountAddressChanged: _reload()

    // Accounts holding nothing (the stub has no per-account balances otherwise):
    // for them no row carries a balance, and an owned-only picker lists nothing.
    property var emptyAccounts: []
    onEmptyAccountsChanged: _reload()
    // kind 0: the real model lists only what the account holds
    property bool ownedOnly: false
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

    // null when the group has nothing on the filtered chain, or nothing the
    // account holds while only holdings are listed
    function _mapGroup(group) {
        let tokens = []
        let balances = []
        const price = (!!group.marketDetails && !!group.marketDetails.currencyPrice)
                      ? group.marketDetails.currencyPrice.amount : 0
        const held = root.emptyAccounts.indexOf(root.accountAddress) === -1
        if (!!group.tokens) {
            for (let i = 0; i < group.tokens.ModelCount.count; i++) {
                const t = ModelUtils.get(group.tokens, i)
                tokens.push({ key: t.key, chainId: t.chainId })
                if (root.enabledChainId !== -1 && t.chainId !== root.enabledChainId)
                    continue
                if (!held)
                    continue
                balances.push({
                    chainId: t.chainId,
                    iconUrl: "",
                    chainName: "",
                    balance: root.syntheticBalance,
                    rawBalance: "1000000000000000000000000000000"
                })
            }
        }
        if ((root.enabledChainId !== -1 || root.ownedOnly) && balances.length === 0)
            return null
        const balance = held ? root.syntheticBalance : 0
        return {
            key: group.key,
            groupKey: group.key,
            name: group.name,
            symbol: group.symbol,
            logoUri: group.logoUri || "",
            decimals: group.decimals || 18,
            cryptoPrice: price,
            currentBalance: balance,
            currencyBalance: balance * price,
            sectionName: group.sectionName || "",
            balances: balances,
            tokens: tokens
        }
    }

    // Reconcile by key, like the real terminal model: a row that stays keeps its
    // identity (dataChanged), one whose key is gone is removed, a new key is
    // appended. Rows are never rewritten under another key, so a selection bound
    // by key (ModelEntry) survives a source or chain-filter change.
    function _indexOfKey(key) {
        for (let i = 0; i < count; i++)
            if (get(i).key === key)
                return i
        return -1
    }

    function _syncRows(newRows) {
        const newKeys = new Set(newRows.map(r => r.key))
        for (let i = count - 1; i >= 0; i--)
            if (!newKeys.has(get(i).key))
                remove(i, 1)
        for (const row of newRows) {
            const idx = _indexOfKey(row.key)
            if (idx === -1)
                append(row)
            else
                set(idx, row)
        }
    }

    function _reload() {
        let newRows = []
        if (!!sourceModel) {
            for (let i = 0; i < sourceModel.ModelCount.count; i++) {
                const row = _mapGroup(ModelUtils.get(sourceModel, i))
                if (!!row)
                    newRows.push(row)
            }
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

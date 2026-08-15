import QtQuick

import StorybookMocks

import Mocks

/*!
    Fully configurable mock wallet profile backing the real wallet stores, shared
    by the storybook page (benchmarks) and — once they exist — the qml tests.

    Unlike CommunitySectionMock, which writes into stub store singletons, this one
    writes into the nim context-property mocks (walletSectionAccounts,
    walletSectionAssets, …). The wallet stores themselves are the production ones,
    so the store/adaptor/SFPM chain under measurement is the real one.

    Configure the scale properties, then call install(); call uninstall() in
    cleanup — the context mocks are engine-global and every page sees them.

    Generation is deterministic: everything derives from `seed`, no Date.now(),
    no Math.random().
*/
QtObject {
    id: root

    // Scale. Defaults are the realistic-whale profile; the page's spinboxes go
    // to 10x from here.
    property int seed: 1
    property int accountCount: 8
    property int assetGroupCount: 2000
    property int collectibleCount: 500
    property int communityCount: 5
    property int savedAddressCount: 20
    property int followingAddressCount: 120
    property int collectiblesPageSize: 100

    // State toggles
    property bool watchOnlyOnly: false
    property bool singleAccount: false
    property bool emptyWallet: false
    property bool testNetworksEnabled: false

    readonly property WalletMockProfile profile: WalletMockProfile {
        seed: root.seed
        accountCount: root.emptyWallet ? 0 : (root.singleAccount ? 1 : root.accountCount)
        assetGroupCount: root.emptyWallet ? 0 : root.assetGroupCount
        collectibleCount: root.emptyWallet ? 0 : root.collectibleCount
        communityCount: root.emptyWallet ? 0 : root.communityCount
        savedAddressCount: root.emptyWallet ? 0 : root.savedAddressCount
        followingAddressCount: root.emptyWallet ? 0 : root.followingAddressCount
        collectiblesPageSize: root.collectiblesPageSize
        watchOnlyOnly: root.watchOnlyOnly
        chainIds: root.chainIds
    }

    // Chains the generated tokens spread over — the active networks of the same
    // model the networks mock serves, so token chainIds always resolve.
    property var chainIds: {
        const ids = []
        const model = NetworksModel.flatNetworks
        for (let i = 0; i < model.count; ++i) {
            const network = model.get(i)
            if (network.isActive && network.isTest === root.testNetworksEnabled)
                ids.push(network.chainId)
        }
        return ids
    }

    readonly property ListModel accountsModel: ListModel {}
    readonly property ListModel communitiesModel: ListModel {}

    // Static: the on-ramp provider list does not vary with the profile
    readonly property OnRampProvidersModel buyProvidersModel: OnRampProvidersModel {}

    readonly property AddAccountModuleMock addAccountModule: AddAccountModuleMock {
        accountsModel: root.accountsModel
    }

    // Terminal token-selector picker, built on demand when a modal opens.
    readonly property Component tokenSelectorModelComponent: Component {
        TokenSelectorModelMock {}
    }

    function _fill(model, rows) {
        model.clear()
        for (let i = 0; i < rows.length; ++i)
            model.append(rows[i])
    }

    function _totalBalance() {
        let total = 0
        for (let i = 0; i < root.accountsModel.count; ++i)
            total += root.accountsModel.get(i).currencyBalance.amount
        return total
    }

    function rebuild() {
        profile.generate()
        _fill(root.accountsModel, profile.accounts())
        _fill(root.communitiesModel, profile.communities())
    }

    function install() {
        rebuild()

        networksModule.areTestNetworksEnabled = root.testNetworksEnabled
        networksModule.enabledChainIds = root.chainIds.join(":")

        walletSectionAccounts.accounts = root.accountsModel
        walletSectionAccounts.profile = profile

        walletSectionAssets.groupedAccountAssetsModel = profile.groupedAccountAssetsModel

        walletSectionAssetsView.assetsModel = profile.assetsModel
        walletSectionAssetsView.profile = profile

        walletSectionAllTokens.tokenGroupsModel = profile.tokenGroupsModel

        walletSectionAllCollectibles.allCollectiblesModel = profile.collectiblesModel

        walletSectionBuySellCrypto.model = root.buyProvidersModel

        walletSection.addAccountModule = root.addAccountModule

        walletSectionFollowingAddresses.profile = profile
        _fill(walletSectionSavedAddresses.model, profile.savedAddresses())

        walletSectionTokenSelector.modelFactory = kind =>
            root.tokenSelectorModelComponent.createObject(root, {
                sourceModel: profile.tokenGroupsModel
            })

        _fill(communitiesModule.model, profile.communities())

        const total = _totalBalance()
        walletSection.totalCurrencyBalance = ({
            amount: total, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false
        })
        walletSectionOverview.currencyBalance = walletSection.totalCurrencyBalance
        walletSectionOverview.colorIds = _allColorIds()
        selectAccount(-1)
    }

    // ";"-separated, like overview/view.nim — the header gradient splits on it
    function _allColorIds() {
        const ids = []
        for (let i = 0; i < root.accountsModel.count; ++i)
            ids.push(root.accountsModel.get(i).colorId)
        return ids.length > 0 ? ids.join(";") : "primary"
    }

    function uninstall() {
        walletSectionAccounts.accounts = walletSectionAccounts.emptyAccounts
        walletSectionAccounts.profile = null
        walletSectionAssets.groupedAccountAssetsModel = walletSectionAssets.emptyModel
        walletSectionAssetsView.assetsModel = walletSectionAssetsView.emptyModel
        walletSectionAssetsView.profile = null
        walletSectionAllTokens.tokenGroupsModel = walletSectionAllTokens.emptyModel
        walletSectionAllCollectibles.allCollectiblesModel = walletSectionAllCollectibles.emptyModel
        walletSectionBuySellCrypto.model = walletSectionBuySellCrypto.emptyModel
        walletSection.addAccountModule = null
        walletSectionFollowingAddresses.profile = null
        walletSectionFollowingAddresses.model.clear()
        walletSectionSavedAddresses.model.clear()
        walletSectionTokenSelector.modelFactory = null
        communitiesModule.model.clear()
        profile.clear()
        root.accountsModel.clear()
        root.communitiesModel.clear()
    }

    // --- Dynamics (decision 9)

    // Account switch: filter the section to one address and repoint the overview,
    // the way LeftTabView's onAccountSelected does through the store.
    function selectAccount(index) {
        if (index < 0 || index >= root.accountsModel.count) {
            walletSection.setFilterAllAddresses()
            return
        }
        walletSection.setFilterAddress(root.accountsModel.get(index).address)
    }

    // Nim repoints the overview off the address filter, so clicking an account in
    // the left panel is enough there. Here that happens on filterChanged, which
    // both the page's switch button and LeftTabView end up in.
    readonly property Connections _filterConnections: Connections {
        target: walletSection
        function onFilterChanged(address) { root._repointOverview(address) }
    }

    function _repointOverview(address) {
        if (!address) {
            walletSectionOverview.isAllAccounts = true
            walletSectionOverview.name = qsTr("All accounts")
            walletSectionOverview.mixedcaseAddress = ""
            walletSectionOverview.currencyBalance = walletSection.totalCurrencyBalance
            walletSectionOverview.colorIds = _allColorIds()
            walletSectionOverview.isWatchOnlyAccount = false
            walletSectionOverview.canSend = true
            return
        }
        const account = profile.accountByAddress(address)
        if (!account || !account.address)
            return
        walletSectionOverview.isAllAccounts = false
        walletSectionOverview.name = account.name
        walletSectionOverview.mixedcaseAddress = account.mixedcaseAddress
        walletSectionOverview.currencyBalance = account.currencyBalance
        walletSectionOverview.colorId = account.colorId
        walletSectionOverview.colorIds = account.colorId
        walletSectionOverview.emoji = account.emoji
        walletSectionOverview.isWatchOnlyAccount = account.walletType === "watch"
        walletSectionOverview.canSend = account.canSend
    }

    // Token reload: the loading flags flip, balances move, the flags clear.
    function reloadTokens() {
        walletSection.isAccountTokensReloading = true
        walletSectionOverview.balanceLoading = true
        profile.setAssetsLoading(true)
        profile.refreshBalances()
        profile.setAssetsLoading(false)
        walletSectionOverview.balanceLoading = false
        walletSection.isAccountTokensReloading = false
        walletSection.lastReloadTimestamp = walletSection.lastReloadTimestamp + 1
    }

    function loadMoreCollectibles() {
        profile.loadMoreCollectibles()
    }
}

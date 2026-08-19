import QtQuick

// Required mock of: src/app/modules/main/wallet_section/view.nim
//
// Empty by default — it is instantiated once per engine and every storybook page
// sees it. WalletSectionMock.install() fills it for the pages that want data.

Item {
    id: root

    readonly property string contextPropertyName: "walletSection"

    readonly property bool walletReady: true

    property string currentCurrency: "USD"
    property string addressFilters: ""

    // The addresses "all accounts" resolves to, filled by WalletSectionMock.
    // Nim joins the wallet's non-hidden addresses here, and the collectibles
    // views read ownership balances through that list - an empty one hides
    // every collectible.
    property var allFilterAddresses: []
    property var keypairImportModule: null
    property var addAccountModule: null
    property bool isNonArchivalNode: false
    property bool hasPairedDevices: false
    property string keypairOperabilityForObservedAccount: ""
    property bool isAccountTokensReloading: false
    property double lastReloadTimestamp: 0

    property var totalCurrencyBalance: ({
        amount: 0, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false
    })

    // Kept self-contained: the mocks are created in directory order, so reading
    // another context property from here would depend on registration order.
    readonly property QtObject overview: QtObject {
        readonly property string mixedcaseAddress: ""
    }

    readonly property QtObject activityController: QtObject {
        readonly property double noLimitTimestamp: 0

        property var model: emptyActivityModel
        property var collectiblesModel: emptyActivityModel
        property var recipientsModel: emptyActivityModel

        readonly property QtObject status: QtObject {
            property bool loadingData: false
            property bool newDataAvailable: false
            property bool isFilterDirty: false
            property bool loadingCollectibles: false
            property bool loadingRecipients: false
            property double startTimestamp: 0
        }

        function setFilterTime(from, to) {}
        function setFilterType(types) {}
        function setFilterStatus(statuses) {}
        function setFilterAssets(assets, includeAll) {}
        function setFilterToAddresses(addresses) {}
        function setFilterCollectibles(collectibles) {}
        function updateFilter() {}
        function updateCollectiblesModel() {}
        function loadMoreCollectibles() {}
        function updateRecipientsModel() {}
        function updateStartTimestamp() {}
        function resetActivityData() {}
        function loadMoreItems() {}
    }

    readonly property ListModel emptyActivityModel: ListModel {
        readonly property bool hasMore: false
    }

    // The filter slots are what RightTabView calls before it navigates to the
    // collectible detail; missing ones threw out of the navigation handler and
    // the detail never opened.
    component TmpActivityController: QtObject {
        readonly property var model: root.emptyActivityModel
        readonly property QtObject status: QtObject {
            readonly property bool loadingData: false
            readonly property bool newDataAvailable: false
        }

        function resetFilter() {}
        function setFilterAddressesJson(addresses, allAddresses) {}
        function setFilterChainsJson(chains, allChains) {}
        function setFilterCollectibles(collectibles) {}
        function updateFilter() {}
    }

    readonly property TmpActivityController tmpActivityController0: TmpActivityController {}
    readonly property TmpActivityController tmpActivityController1: TmpActivityController {}

    property var walletConnectController: null
    property var dappsConnectorController: null

    readonly property QtObject collectibleDetailsController: QtObject {
        property var detailedEntry: null
        property bool isDetailedEntryLoading: false

        // Set by WalletSectionMock; nim resolves the entry out of the wallet's
        // own collectibles, which only the profile mock knows about here.
        property var detailedEntryResolver: null

        readonly property QtObject status: QtObject {
            property bool loadingData: false
            property bool loadingCollectibles: false
            property bool newDataAvailable: false
        }

        function getDetailedCollectible(chainId, contractAddress, tokenId) {
            detailedEntry = !!detailedEntryResolver
                    ? detailedEntryResolver(chainId, contractAddress, tokenId) : null
        }
        function resetDetailedCollectible() { detailedEntry = null }
    }

    signal filterChanged(string addresses)
    signal displayAddAccountPopup
    signal destroyAddAccountPopup
    signal displayKeypairImportPopup
    signal destroyKeypairImportPopup
    signal walletAccountRemoved(string address)
    signal txDecoded(string txHash, string dataDecoded)

    function setFilterAddress(address) { root.addressFilters = address; root.filterChanged(address) }
    // Nim sets addressFilters to the joined address list but still signals ""
    // for all-accounts (module.nim updateViewWithAddressFilterChanged).
    function setFilterAllAddresses() {
        root.addressFilters = root.allFilterAddresses.join(":")
        root.filterChanged("")
    }
    function canProfileProveOwnershipOfProvidedAddresses(addresses) { return true }
    function isChecksumValidForAddress(address) { return true }
    function reloadAccountTokens() {}
    function runAddAccountPopup(addingWatchOnlyAccount) { root.displayAddAccountPopup() }
    function runEditAccountPopup(address) { root.displayAddAccountPopup() }
    function runKeypairImportPopup() { root.displayKeypairImportPopup() }
    function toggleWatchOnlyAccounts() {}
    function fetchDecodedTxData(txHash, data) {}
    function getCurrencyAmount(amount, key) { return "%1 %2".arg(amount).arg(key) }
    function updateCurrency(currency) { root.currentCurrency = currency }
    function getRpcStats() { return "{}" }
    function resetRpcStats() {}
}

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

    readonly property QtObject tmpActivityController0: QtObject {
        readonly property var model: root.emptyActivityModel
        readonly property QtObject status: QtObject {
            readonly property bool loadingData: false
            readonly property bool newDataAvailable: false
        }
    }
    readonly property QtObject tmpActivityController1: QtObject {
        readonly property var model: root.emptyActivityModel
        readonly property QtObject status: QtObject {
            readonly property bool loadingData: false
            readonly property bool newDataAvailable: false
        }
    }

    property var walletConnectController: null
    property var dappsConnectorController: null

    readonly property QtObject collectibleDetailsController: QtObject {
        property var detailedEntry: null
        property bool isDetailedEntryLoading: false

        readonly property QtObject status: QtObject {
            property bool loadingData: false
            property bool loadingCollectibles: false
            property bool newDataAvailable: false
        }

        function getDetailedCollectible(chainId, contractAddress, tokenId) {}
        function resetDetailedCollectible() {}
    }

    signal filterChanged(string addresses)
    signal displayAddAccountPopup
    signal destroyAddAccountPopup
    signal displayKeypairImportPopup
    signal destroyKeypairImportPopup
    signal walletAccountRemoved(string address)
    signal txDecoded(string txHash, string dataDecoded)

    function setFilterAddress(address) { root.addressFilters = address; root.filterChanged(address) }
    function setFilterAllAddresses() { root.addressFilters = ""; root.filterChanged("") }
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

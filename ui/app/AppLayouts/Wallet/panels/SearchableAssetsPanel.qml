import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.views
import AppLayouts.Wallet.controls

import utils


import QtModelsToolkit
import SortFilterProxyModel

/**
  Panel holding search field and lists of assets.
*/
Control {
    id: root

    /**
        Expected model structure:

        key                     [string] - refers to token group key
        name                    [string] - name
        symbol                  [string] - symbol
        decimals                [int] - decimals
        logoUri                 [string] - icon
        currentBalance          [double] - token balance summed over the listed chains
        currencyBalance         [double] - fiat balance; formatted to a string via formatCurrencyBalance
        cryptoPrice             [double] - fiat price per token, to price a single chain's balance
        sectionName (optional)  [string] - text to be rendered as a section
        balances            [model]  - one entry per chain the token has a balance on
            chainId         [int]    - token's chain id
            iconUrl         [string] - network icon
            chainName       [string] - network name
            balance         [double] - balance in logical units (already divided by decimals)
            rawBalance      [string] - raw on-chain wei as a BigInt string
    **/
    property var model
    property string highlightedKey
    /** chain of the highlighted holding; only used to disambiguate the per-chain rows **/
    property int highlightedChainId: -1
    property string nonInteractiveKey
    property bool showSectionName: true

    // Formats the numeric `currencyBalance` role into the localized fiat string
    // shown per row. Sites inject a formatter aware of the user-selected display
    // currency; the default falls back to the system locale's currency.
    property var formatCurrencyBalance: (amount) => (amount === undefined ? "" : Number(amount).toLocaleCurrencyString(Qt.locale()))

    /** networks catalog for the chain-filter chip row; roles: chainId, chainName, iconUrl.
        The chip row is shown only when this is set. **/
    property var flatNetworksModel

    /** currently selected chain in the chip row; -1 = All. Input only, see NetworkChipFilter **/
    property int selectedChainId: -1
    signal chainSelected(int chainId)

    /** fallback chain icon (raw iconUrl) for rows without a per-chain balance **/
    property string defaultNetworkIcon

    // Lazy loading properties
    property bool hasMoreItems: false
    property bool isLoadingMore: false

    /** with no chain filter, list a holding once per chain it sits on **/
    readonly property bool expandPerChain: !!root.flatNetworksModel && root.selectedChainId === -1

    signal search(string keyword)
    /** chainId is -1 for an aggregate row, i.e. the caller picks the chain itself **/
    signal selected(string key, int chainId)
    signal loadMoreRequested()

    function clearSearch() {
        searchBox.text = ""
    }

    QtObject {
        id: d

        readonly property int numOfItemsFromBottomToTriggerFetching: 3

        readonly property bool validSearchResultExists: !!searchBox.text && root.model.ModelCount.count > 0

        property var debounceLoadMore: Backpressure.debounce(root, 1000, function() {
            root.loadMoreRequested()
        })

        property var debounceSearch: Backpressure.debounce(root, 500, function(keyword) {
            root.search(keyword)
        })

        function loadMoreRequested() {
            Qt.callLater(debounceLoadMore)
        }

        function search(keyword) {
            Qt.callLater(debounceSearch, keyword)
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            text: qsTr("Your assets will appear here")
            color: Theme.palette.baseColor1
            visible: !listView.count && !searchBox.text
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.halfPadding
            visible: listView.count || !!searchBox.text || root.flatNetworksModel

            TokenSearchBox {
                id: searchBox

                objectName: "searchBox"

                Layout.fillWidth: true
                placeholderText: qsTr("Search for token or enter token address")

                onTextChanged: {
                    d.search(text)
                }

                Keys.forwardTo: [listView]
            }

            StatusButton {
                objectName: "pasteButton"
                Layout.rightMargin: Theme.halfPadding
                size: StatusBaseButton.Size.Small
                font.weight: Font.Normal
                icon.name: "paste"
                text: qsTr("Paste")
                focusPolicy: Qt.NoFocus
                visible: !searchBox.text
                onClicked: {
                    searchBox.forceActiveFocus()
                    searchBox.text = ClipboardUtils.text
                }
            }
        }

        NetworkChipFilter {
            objectName: "chainFilter"

            Layout.fillWidth: true
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Theme.halfPadding
            Layout.topMargin: 4
            Layout.bottomMargin: 4

            visible: !!root.flatNetworksModel

            flatNetworksModel: root.flatNetworksModel
            selectedChainId: root.selectedChainId
            onChainSelected: (chainId) => root.chainSelected(chainId)
        }

        StatusDialogDivider {
            Layout.fillWidth: true
            visible: listView.count
        }

        StatusListView {
            id: listView

            objectName: "assetsListView"
            // TODO: add Component.onReusued
            reuseItems: false

            clip: true

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            Layout.leftMargin: 4
            Layout.rightMargin: 4

            spacing: 4

            model: root.model && root.model.ModelCount.count > 0 ? root.model : null
            section.property: "sectionName"

            section.delegate: TokenSelectorSectionDelegate {
                width: ListView.view.width
                text: section
                height: root.showSectionName ? implicitHeight : 0
            }

            delegate: Column {
                id: holdingRows

                required property var model
                required property int index

                width: ListView.view.width
                spacing: listView.spacing

                readonly property ModelChangeTracker balancesTracker: ModelChangeTracker {
                    model: holdingRows.model.balances
                }

                readonly property var chainRows: {
                    holdingRows.balancesTracker.revision
                    const balances = holdingRows.model.balances
                    if (!root.expandPerChain || !balances || balances.count < 2)
                        return [null]
                    return ModelUtils.modelToArray(balances, ["chainId", "balance"])
                }

                /** the rendered rows for this holding; 1 unless split per chain **/
                readonly property int rowCount: rowsRepeater.count
                function rowAt(i) {
                    return rowsRepeater.itemAt(i)
                }

                function selectFirst() {
                    rowsRepeater.itemAt(0).clicked()
                }

                Repeater {
                    id: rowsRepeater

                    model: holdingRows.chainRows

                    delegate: TokenSelectorAssetDelegate {
                        required property var modelData
                        required property int index

                        readonly property var holding: holdingRows.model
                        readonly property int rowChainId: !!modelData ? modelData.chainId : -1

                        width: holdingRows.width

                        chainId: rowChainId
                        highlighted: holding.key === root.highlightedKey
                                     && (rowChainId === -1 || rowChainId === root.highlightedChainId)
                        enabled: holding.key !== root.nonInteractiveKey
                        isAutoHovered: d.validSearchResultExists && holdingRows.index === 0
                                       && index === 0 && !listViewHoverHandler.hovered

                        name: holding.name
                        symbol: holding.symbol
                        currencyBalanceAsString: root.formatCurrencyBalance(
                            !!modelData ? modelData.balance * (holding.cryptoPrice ?? 0)
                                        : holding.currencyBalance)
                        iconSource: holding.logoUri || Constants.tokenIcon(holding.symbol)
                        balancesModel: holding.balances
                        tokensModel: holding.tokens
                        currentBalance: !!modelData ? modelData.balance : (holding.currentBalance ?? 0)
                        defaultNetworkIcon: root.defaultNetworkIcon

                        onClicked: root.selected(holding.key, rowChainId)
                    }
                }

                // Trigger load more when user is d.numOfItemsFromBottomToTriggerFetching items away from bottom
                Component.onCompleted: {
                    if (root.hasMoreItems && !root.isLoadingMore) {
                        const itemsFromBottom = listView.count - index - 1
                        if (itemsFromBottom <= d.numOfItemsFromBottomToTriggerFetching) {
                            d.loadMoreRequested()
                        }
                    }
                }
            }

            onContentYChanged: {
                if (root.hasMoreItems && !root.isLoadingMore && listView.count > 0) {
                    const bottom = contentY + height
                    const total = contentHeight
                    // Trigger when d.numOfItemsFromBottomToTriggerFetching items away from bottom (estimate ~70px per item)
                    const itemHeight = 70
                    if (bottom >= total - (d.numOfItemsFromBottomToTriggerFetching * itemHeight)) {
                        d.loadMoreRequested()
                    }
                }
            }

            Keys.onReturnPressed: {
                if(d.validSearchResultExists)
                    listView.itemAtIndex(0).selectFirst()
            }

            Keys.onEnterPressed: {
                if(d.validSearchResultExists)
                    listView.itemAtIndex(0).selectFirst()
            }

            HoverHandler {
                id: listViewHoverHandler
            }

            // Loading indicator at the bottom
            footer: Loader {
                width: ListView.view ? ListView.view.width : 0
                active: root.hasMoreItems
                visible: active

                sourceComponent: Item {
                    height: 70
                    width: parent.width

                    StatusLoadingIndicator {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        color: Theme.palette.primaryColor1
                    }

                    StatusBaseText {
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Loading more tokens...")
                        color: Theme.palette.baseColor1
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}

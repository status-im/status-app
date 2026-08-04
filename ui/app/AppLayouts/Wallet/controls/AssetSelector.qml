import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Utils

import AppLayouts.Wallet.panels

import utils

Control {
    id: root

    /** Expected model structure: see SearchableAssetsPanel::model **/
    property var model

    property string nonInteractiveKey

    property bool hasMoreItems: false
    property bool isLoadingMore: false

    /** Forwarded to SearchableAssetsPanel; see its formatCurrencyBalance. **/
    property var formatCurrencyBalance: (amount) => (amount === undefined ? "" : Number(amount).toLocaleCurrencyString(Qt.locale()))

    /** networks catalog for the in-panel chain-filter chip row (optional) **/
    property var flatNetworksModel
    /** selected chain in the chip row; -1 = All. Input only, see NetworkChipFilter **/
    property int selectedChainId: -1
    signal chainSelected(int chainId)

    /** chain of the currently selected holding, to highlight the right per-chain row **/
    property int highlightedChainId: -1

    /** network icon badge for the selected token button (optional) **/
    property url selectedNetworkIcon
    /** fallback chain icon (raw iconUrl) for list rows without a per-chain balance **/
    property string defaultNetworkIcon

    readonly property bool isSelected: button.selected

    signal search(string keyword)
    /** chainId is -1 when the row didn't pin one down; the caller then picks it **/
    signal selected(string groupKey, int chainId)
    signal loadMoreRequested()

    function setSelection(symbol, icon, tokenGroupKey) {
        button.name = symbol
        button.icon = icon
        button.selected = true

        searchableAssetsPanel.highlightedKey = tokenGroupKey ?? ""
    }

    function reset() {
        button.selected = false
        searchableAssetsPanel.highlightedKey = ""
    }

    QtObject {
        id: d
        readonly property int windowHeight: !!contentItem.Window.window ? contentItem.Window.window.height: 0
        readonly property int bottomPadding: 60
    }

    contentItem: TokenSelectorButton {
        id: button

        objectName: "tokenSelectorButton"

        forceHovered: dropdown.opened
        text: qsTr("Select asset")
        networkIcon: root.selectedNetworkIcon

        onClicked: dropdown.opened ? dropdown.close() : dropdown.open()
    }

    StatusDropdown {
        id: dropdown

        objectName: "dropdown"

        directParent: root
        relativeY: root.height + 4
        relativeX: root.width - width

        width: 448
        height: Math.min(implicitHeight, d.windowHeight - button.mapToItem(null, 0, button.height).y - d.bottomPadding)
        fillHeightOnBottomSheet: true

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        padding: 0

        contentItem: SearchableAssetsPanel {
            id: searchableAssetsPanel

            objectName: "searchableAssetsPanel"

            model: root.model
            nonInteractiveKey: root.nonInteractiveKey
            hasMoreItems: root.hasMoreItems
            isLoadingMore: root.isLoadingMore
            formatCurrencyBalance: root.formatCurrencyBalance

            flatNetworksModel: root.flatNetworksModel
            selectedChainId: root.selectedChainId
            highlightedChainId: root.highlightedChainId
            defaultNetworkIcon: root.defaultNetworkIcon
            onChainSelected: (chainId) => root.chainSelected(chainId)

            onLoadMoreRequested: root.loadMoreRequested()

            function setCurrentAndClose(symbol, icon, tokenGroupKey) {
                root.setSelection(symbol, icon, tokenGroupKey)
                dropdown.close()
            }

            onSelected: function(key, chainId) {
                const entry = ModelUtils.getByKey(root.model, "key", key) // refers to group key
                if (!entry) {
                    console.error("asset couldn't be resolved for the key", key)
                    return
                }

                setCurrentAndClose(entry.symbol, entry.logoUri || Constants.tokenIcon(entry.symbol), entry.key)
                root.selected(entry.key, chainId)
            }

            onSearch: function(keyword) {
                root.search(keyword)
            }
        }

        onClosed: {
            searchableAssetsPanel.clearSearch()
        }
    }
}

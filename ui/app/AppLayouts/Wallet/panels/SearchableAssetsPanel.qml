import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.views

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
        currencyBalanceAsString [string] - formatted balance
        sectionName (optional)  [string] - text to be rendered as a section
        balances            [model]  - contains a single entry for (token, accountAddress) pair
            account         [string] - wallet account address
            groupKey        [string] - group key that the token belongs to (cross chain id or token key if cross chain id is empty)
            tokenKey        [string] - token unique key (chain - address)
            chainId         [int]    - token's chain id
            tokenAddress    [string] - token's address (contract)
            balance         [string] - raw balance that the `account` has for token with `tokenKey`
            balanceAsString [string] - display value for balance that the `account` has for token with `tokenKey`
    **/
    property var model
    property string highlightedKey
    property string nonInteractiveKey
    property bool showSectionName: true

    // Lazy loading properties
    property bool hasMoreItems: false
    property bool isLoadingMore: false

    signal search(string keyword)
    signal selected(string key)
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

        property var debounceSearch: Backpressure.debounce(root, 1000, function(keyword) {
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

        TokenSearchBox {
            id: searchBox

            objectName: "searchBox"

            Layout.fillWidth: true
            placeholderText: qsTr("Search for token or enter token address")

            visible: listView.count || !!searchBox.text

            onTextChanged: {
                d.search(text)
            }

            Keys.forwardTo: [listView]
        }

        StatusDialogDivider {
            Layout.fillWidth: true
            visible: listView.count
        }

        StatusListView {
            id: listView

            objectName: "assetsListView"

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

            delegate: TokenSelectorAssetDelegate {
                required property var model
                required property int index

                width: ListView.view.width

                highlighted: model.key === root.highlightedKey
                enabled: model.key !== root.nonInteractiveKey
                balancesListInteractive: !ListView.view.moving
                isAutoHovered: d.validSearchResultExists && index === 0 && !listViewHoverHandler.hovered

                name: model.name
                symbol: model.symbol
                currencyBalanceAsString: model.currencyBalanceAsString ?? ""
                iconSource: model.logoUri
                balancesModel: model.balances

                onClicked: root.selected(model.key)

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
                    listView.itemAtIndex(0).clicked()
            }

            Keys.onEnterPressed: {
                if(d.validSearchResultExists)
                    listView.itemAtIndex(0).clicked()
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

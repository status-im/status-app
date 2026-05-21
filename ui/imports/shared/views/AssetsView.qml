import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.controls
import shared.controls
import shared.popups
import utils

import SortFilterProxyModel


Control {
    id: root

    /**
      Expected model structure:

        key                         [string]    - refers to token group key
        name                        [string]    - token's name
        symbol                      [string]    - token's symbol
        decimals                    [int]       - token's decimals
        logoUri                     [string]    - token's image
        tokens                      [model]     - contains tokens that belong to the same token group (a single token per chain), has at least a single token
            key                     [string]    - token key
            groupKey                [string]    - token group key
            crossChainId            [string]    - cross chain id
            address                 [string]    - token's address
            name:                   [string]    - token's name
            symbol:                 [string]    - token's symbol
            decimals:               [int]       - token's decimals
            chainId:                [int]       - token's chain id
            image:                  [string]    - token's image
            customToken             [bool]      - `true` if the it's a custom token
            communityId             [string]    - contains community id if the token is a community token
        balances                    [model]     - contains a single entry for (token, accountAddress) pair
            account                 [string]    - wallet account address
            groupKey                [string]    - group key that the token belongs to (cross chain id or token key if cross chain id is empty)
            tokenKey                [string]    - token unique key (chain - address)
            chainId                 [int]       - token's chain id
            tokenAddress            [string]    - token's address
            balance                 [string]    - balance that the `account` has for token with `tokenKey`
        communityId                 [string]    - for community assets, unique identifier of a community, e.g. "0x6734235"
        communityName               [string]    - for community assets, name of a community e.g. "Crypto Kitties"
        communityIcon               [url]       - for community assets, community's icon url
        websiteUrl                  [string]    - token's website
        description                 [string]    - token's description
        marketDetails               [object]    - contains market data
            changePctHour           [double]    - percentage change hour
            changePctDay            [double]    - percentage change day
            changePct24hour         [double]    - percentage change 24 hrs
            change24hour            [double]    - change 24 hrs
            marketCap               [object]
                amount              [double]    - market capitalization value
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            highDay                 [object]
                amount              [double]    - the highest value for day
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            lowDay                  [object]
                amount              [double]    - the lowest value for day
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
            currencyPrice           [object]
                amount              [double]    - token's price
                symbol              [string]    - currency, eg. "USD"
                displayDecimals     [int]       - decimals to display
                stripTrailingZeroes [bool]      - strip leading zeros
        detailsLoading              [bool]      - `true` if details are still being loaded
        balance                     [double]    - tokens balance is the commonly used unit, e.g. 1.2 for 1.2 ETH, used for sorting and computing market value
        balanceText                 [string]    - formatted and localized balance. This is not done internally because it may depend on many external factors
        balanceLoading              [bool]      - true while at least one of the per-(chain, account) balances has not been fetched yet
        error                       [string]    - error message related to balance
        marketDetailsAvailable      [bool]      - specifies if market datails are available for given token
        marketDetailsLoading        [bool]      - specifies if market datails are available for given token
        marketPrice                 [double]    - specifies market price in currently used currency
        marketChangePct24hour       [double]    - percentage price change in last 24 hours, e.g. 0.5 for 0.5% of price change
        visible                     [bool]      - determines if token is displayed or not
        position                    [int]       - token's position
        canBeHidden                 [bool]      - specifies if given token can be hidden (e.g. ETH should be always visible)
    **/
    property var model

    // enables global loading state useful when real data are not yet available
    property bool loading

    // shows/hides list sorter
    property bool sorterVisible

    // allows/disables choosing custom sort order from a sorter
    property bool customOrderAvailable

    // switches configuring right click menu
    property bool sendEnabled: true
    property bool communitySendEnabled: false
    property bool swapEnabled: true
    property bool swapVisible: true
    property bool communitySwapVisible: false

    property string balanceError
    // banner component to be displayed on top of the list
    property alias bannerComponent: banner.sourceComponent

    // global market data error, presented for all tokens expecting market data
    property string marketDataError

    // formatting function for fiat currency values
    property var formatFiat: balance => `${balance.toLocaleCurrencyString(Qt.locale())}`

    signal sendRequested(string key)
    signal receiveRequested(string key)
    signal swapRequested(string key)
    signal assetClicked(string key)
    signal communityClicked(string communityKey)
    signal hideRequested(string key)
    signal hideCommunityAssetsRequested(string communityKey)
    signal manageTokensRequested

    function setSortOrder(order) {
        d.sortOrder = order
    }

    function getSortOrder() {
        return d.sortOrder
    }

    function getSortValue() {
        return d.sortValue
    }

    function sortByValue(value) {
        d.sortValue = value
    }

    QtObject {
        id: d

        readonly property int loadingItemsCount: 25
        property int sortOrder: Qt.DescendingOrder
        property int sortValue: -1
    }

    SortFilterProxyModel {
        id: sfpm

        sourceModel: root.model ?? null

        proxyRoles: [
            // helper role for rendering section delegate
            FastExpressionRole {
                name: "isCommunity"
                expression: !!model.communityId ? "community" : ""
                expectedRoles: ["communityId"]
            },
            FastExpressionRole {
                name: "marketBalance"
                expression: model.balance * model.marketPrice
                expectedRoles: ["balance", "marketPrice"]
            },
            FastExpressionRole {
                name: "change1DayFiat"
                expression: model.marketBalance * (1 - (1 / (model.marketChangePct24hour / 100 + 1)))
                expectedRoles: ["marketBalance", "marketChangePct24hour"]
            }
        ]

        sorters: [
            RoleSorter {
                roleName: "isCommunity"
            },
            RoleSorter {
                roleName: sortOrderComboBox.currentSortRoleName
                sortOrder: sortOrderComboBox.currentSortOrder
            }
        ]
    }

    contentItem: ColumnLayout {
        ColumnLayout {
            Layout.fillHeight: false
            Layout.preferredHeight: root.sorterVisible ? implicitHeight : 0

            opacity: root.sorterVisible ? 1 : 0
            spacing: 20
            visible: opacity > 0

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            StatusDialogDivider { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false

                spacing: Theme.halfPadding

                StatusBaseText {
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    text: qsTr("Sort by:")
                }

                SortOrderComboBox {
                    id: sortOrderComboBox

                    objectName: "cmbTokenOrder"
                    hasCustomOrderDefined: root.customOrderAvailable
                    Binding on currentIndex {
                        value: {
                            sortOrderComboBox.count
                            let id = sortOrderComboBox.indexOfValue(d.sortValue)
                            if (id === -1)
                                id = sortOrderComboBox.indexOfValue(SortOrderComboBox.TokenOrderAlpha)
                            return id
                        }
                        when: sortOrderComboBox.count > 0
                    }
                    onCurrentValueChanged: d.sortValue = sortOrderComboBox.currentValue
                    Binding on currentSortOrder {
                        value: d.sortOrder
                    }
                    onCurrentSortOrderChanged: d.sortOrder = sortOrderComboBox.currentSortOrder
                    model: [
                        { value: SortOrderComboBox.TokenOrderCurrencyBalance,
                            text: qsTr("Asset balance value"), icon: "", sortRoleName: "marketBalance" },
                        { value: SortOrderComboBox.TokenOrderBalance,
                            text: qsTr("Asset balance"), icon: "", sortRoleName: "balance" },
                        { value: SortOrderComboBox.TokenOrderCurrencyPrice,
                            text: qsTr("Asset value"), icon: "", sortRoleName: "marketPrice" },
                        { value: SortOrderComboBox.TokenOrder1DChange,
                            text: qsTr("1d change: balance value"), icon: "", sortRoleName: "change1DayFiat" },
                        { value: SortOrderComboBox.TokenOrderAlpha,
                            text: qsTr("Asset name"), icon: "", sortRoleName: "name" },
                        { value: SortOrderComboBox.TokenOrderCustom,
                            text: qsTr("Custom order"), icon: "", sortRoleName: "position" },
                        { value: SortOrderComboBox.TokenOrderNone,
                            text: "---", icon: "", sortRoleName: "" }, // separator
                        { value: SortOrderComboBox.TokenOrderCreateCustom,
                            text: hasCustomOrderDefined ? qsTr("Edit custom order →") : qsTr("Create custom order →"),
                            icon: "", sortRoleName: "" }
                    ]
                    onCreateOrEditRequested: {
                        root.manageTokensRequested()
                    }
                }
            }

            StatusDialogDivider { Layout.fillWidth: true }
        }

        Loader {
            id: banner
            Layout.fillWidth: true
        }

        DelegateModel {
            id: regularModel

            model: sfpm

            delegate: TokenDelegate {
                objectName: `AssetView_TokenListItem_${model.symbol}` // TODO: use model.key

                width: ListView.view.width

                name: model.name
                icon: model.logoUri
                balance: model.balanceText
                balanceLoading: model.balanceLoading
                marketBalance: root.formatFiat(model.marketBalance)

                marketDetailsAvailable: model.marketDetailsAvailable
                marketDetailsLoading: model.marketDetailsLoading
                marketCurrencyPrice: root.formatFiat(model.change1DayFiat)
                marketChangePct24hour: model.marketChangePct24hour

                communityId: model.communityId
                communityName: model.communityName ?? ""
                communityIcon: model.communityImage ?? ""

                errorTooltipText_1: model.error
                errorTooltipText_2: root.marketDataError

                errorMode: !!root.balanceError
                errorIcon.tooltip.text: root.balanceError

                onClicked: function (itemId, mouse) {
                    if (mouse.button === Qt.LeftButton)
                        root.assetClicked(model.key)
                    else if (mouse.button === Qt.RightButton)
                        tokenContextMenu.createObject(this, { model }).popup(mouse.x, mouse.y)
                }

                onCommunityClicked: (communityId) => root.communityClicked(model.communityId)
            }
        }

        DelegateModel {
            id: loadingModel

            model: d.loadingItemsCount

            delegate: LoadingTokenDelegate {
                objectName: `AssetView_LoadingTokenDelegate_${model.index}`

                width: ListView.view.width
            }
        }

        StatusListView {
            id: listView

            objectName: "assetViewStatusListView"

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: root.loading ? loadingModel : regularModel

            section {
                property: "isCommunity"
                delegate: AssetsSectionDelegate {
                    width: parent.width
                    text: qsTr("Community minted")
                    onInfoButtonClicked: communityInfoPopup.createObject(this).open()
                }
            }
        }
    }

    Component {
        id: tokenContextMenu

        AssetContextMenu {
            required property var model

            readonly property string key: model.key
            readonly property string communityKey: model.communityId

            readonly property bool isCommunity: !!model.isCommunity

            onClosed: destroy()

            sendEnabled: root.sendEnabled
                         && (!isCommunity || root.communitySendEnabled)
            swapEnabled: root.swapEnabled
            swapVisible: root.swapVisible && (!isCommunity || root.communitySwapVisible)
            hideVisible: model.canBeHidden
            communityHideVisible: isCommunity

            onSendRequested: root.sendRequested(key)
            onReceiveRequested: root.receiveRequested(key)
            onSwapRequested: root.swapRequested(key)

            onHideRequested: root.hideRequested(key)
            onCommunityHideRequested: root.hideCommunityAssetsRequested(communityKey)

            onManageTokensRequested: root.manageTokensRequested()
        }
    }

    Component {
        id: communityInfoPopup

        CommunityAssetsInfoPopup {
            destroyOnClose: true
        }
    }
}

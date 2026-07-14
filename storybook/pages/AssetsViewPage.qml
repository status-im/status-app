import QtCore
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import shared.views
import utils

import Storybook

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels

import StatusQ
import StatusQ.Popups.Dialog

import SortFilterProxyModel

SplitView {
    id: root

    function format(amount, symbol) {
        return `${amount.toLocaleString(Qt.locale())} ${symbol}`
    }

    // Role-compatible stub for the terminal AssetsAdaptorModel: derives
    // isCommunity/marketBalance/change1DayFiat, filters to visible rows and
    // re-sorts in place via sortBy(roleName, order) — mirrors the Nim model.
    SortFilterProxyModel {
        id: assetsModel

        property int sortRoleOrder: Qt.DescendingOrder
        property string sortRoleName: "name"

        function sortBy(roleName, order) {
            assetsModel.sortRoleName = roleName
            assetsModel.sortRoleOrder = order
        }

        sourceModel: baseAssetsModel
        proxyRoles: [
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
        filters: ValueFilter { roleName: "visible"; value: true }
        sorters: [
            RoleSorter { roleName: "isCommunity" },
            RoleSorter {
                roleName: assetsModel.sortRoleName
                sortOrder: assetsModel.sortRoleOrder
            }
        ]
    }

    ListModel {
        id: baseAssetsModel

        Component.onCompleted: {
            const data = [
                {
                    key: "key_ETH",
                    symbol: "ETH",
                    name: "Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 10.0,
                    balanceLoading: false,

                    marketDetailsAvailable: true,
                    marketDetailsLoading: true,
                    marketPrice: 0,
                    marketChangePct24hour: 0,

                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),

                    position: 2,
                    canBeHidden: false,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_SNT",
                    symbol: "SNT",
                    name: "Status",
                    logoUri: Constants.tokenIcon("SNT", false),
                    balance: 20023.0,
                    balanceLoading: false,

                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 50.23,
                    marketChangePct24hour: 12,

                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),

                    position: 1,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1,10"
                },
                {
                    key: "key_MCT",
                    symbol: "MCT",
                    name: "My custom token",
                    logoUri: Constants.tokenIcon("ZRX", false),
                    balance: 102.4,
                    balanceLoading: false,

                    marketDetailsAvailable: false,
                    marketDetailsLoading: false,
                    marketPrice: 0,
                    marketChangePct24hour: 0,

                    communityId: "34",
                    communityName: "Crypto Kitties",
                    communityImage: Constants.tokenIcon("DAI", false),

                    position: 4,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_DAI",
                    symbol: "DAI",
                    name: "Dai",
                    logoUri: Constants.tokenIcon("DAI", false),
                    balance: 123.24,
                    balanceLoading: false,

                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 23.23,
                    marketChangePct24hour: 2.3,

                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),

                    position: 3,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_USDT",
                    symbol: "USDT",
                    name: "USDT",
                    logoUri: Constants.tokenIcon("USDT", false),
                    balance: 15.24,
                    balanceLoading: false,

                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 0.99,
                    marketChangePct24hour: 0,

                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),

                    position: 5,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_TBT",
                    symbol: "TBT",
                    name: "The best token",
                    logoUri: Constants.tokenIcon("UNI", false),
                    balance: 102,
                    balanceLoading: false,

                    marketDetailsAvailable: false,
                    marketDetailsLoading: false,
                    marketPrice: 0,
                    marketChangePct24hour: 0,

                    communityId: "3423",
                    communityName: "Best tokens",
                    communityImage: Constants.tokenIcon("UNI", false),

                    position: 6,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1,10"
                }
            ]

            append(data)
        }
    }

    SplitView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        orientation: Qt.Vertical

        Pane {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            AssetsView {
                id: assetView
                anchors.fill: parent

                loading: loadingCheckBox.checked
                sorterVisible: sorterVisibleCheckBox.checked
                customOrderAvailable: customOrderAvailableCheckBox.checked

                sendEnabled: sendEnabledCheckBox.checked
                swapEnabled: swapEnabledCheckBox.checked
                swapVisible: swapVisibleCheckBox.checked
                communitySwapVisible: communitySwapVisibleCheckBox.checked

                balanceError: balanceErrorCheckBox.checked
                              ? "Balance error!" : ""

                marketDataError: marketDataErrorCheckBox.checked
                                 ? "Market data error!" : ""

                model: assetsModel
                formatBalance: (balance, key) => root.format(balance, key)
                onSortRequested: (roleName, order) => assetsModel.sortBy(roleName, order)

                onSendRequested: (key) =>logs.logEvent(`send requested: ${key}`)
                onReceiveRequested: (key) => logs.logEvent(`receive requested: ${key}`)
                onSwapRequested: (key) => logs.logEvent(`swap requested: ${key}`)
                onAssetClicked: (key) => logs.logEvent(`asset clicked: ${key}`)
                onCommunityClicked: (communityId) => logs.logEvent(`community clicked: ${communityId}`)

                onHideRequested: (key) => logs.logEvent(`hide requested: ${key}`)
                onHideCommunityAssetsRequested: (communityKey) => logs.logEvent(`hide community assets requested: ${communityKey}`)
                onManageTokensRequested: logs.logEvent(`manage tokens requested`)

                bannerComponent: buyReceiveBannerComponent

                Component {
                    id: buyReceiveBannerComponent
                    BuyReceiveBanner {
                        id: banner
                        topPadding: anyVisibleItems ? 8 : 0
                        bottomPadding: anyVisibleItems ? 20 : 0

                        onCloseBuy: buyEnabled = false
                        onCloseReceive: receiveEnabled = false
                    }
                }
            }
        }

        Logs {
            id: logs
        }

        LogsView {
            clip: true

            SplitView.preferredHeight: 150
            SplitView.fillWidth: true

            logText: logs.logText
        }
    }

    Pane {
        SplitView.preferredWidth: 300

        ColumnLayout {
            CheckBox {
                id: loadingCheckBox

                text: "loading"
            }
            CheckBox {
                id: sorterVisibleCheckBox

                text: "sorter visible"
                checked: false
            }
            CheckBox {
                id: customOrderAvailableCheckBox

                text: "custom order available"
            }
            CheckBox {
                id: sendEnabledCheckBox

                text: "send enabled"
            }
            CheckBox {
                id: swapEnabledCheckBox

                text: "swap enabled"
            }
            CheckBox {
                id: swapVisibleCheckBox

                text: "swap visible"
            }
            CheckBox {
                id: communitySwapVisibleCheckBox

                text: "community swap visible"
            }
            CheckBox {
                id: balanceErrorCheckBox

                text: "balance error"
            }
            CheckBox {
                id: marketDataErrorCheckBox

                text: "market data error"
            }
            ColumnLayout {
                spacing: 5
                Button {
                    text: "Sort desc"
                    onClicked: assetView.setSortOrder(Qt.DescendingOrder)
                }

                Button {
                    text: "Sort asc"
                    onClicked: assetView.setSortOrder(Qt.AscendingOrder)
                }
            }
            ColumnLayout {
                spacing: 10
                Layout.fillWidth: true
                Label {
                    text: "Sort by:"
                }

                ComboBox {
                    id: sortValueComboBox
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    displayText: currentText || ""
                    currentIndex: 4
                    model: [
                        { value: SortOrderComboBox.TokenOrderCurrencyBalance, text: "TokenOrderCurrencyBalance" },
                        { value: SortOrderComboBox.TokenOrderBalance, text: "TokenOrderBalance" },
                        { value: SortOrderComboBox.TokenOrderCurrencyPrice, text: "TokenOrderCurrencyPrice" },
                        { value: SortOrderComboBox.TokenOrder1DChange, text: "TokenOrder1DChange" },
                        { value: SortOrderComboBox.TokenOrderAlpha, text: "TokenOrderAlpha" },
                        { value: SortOrderComboBox.TokenOrderCustom, text: "TokenOrderCustom" }
                    ]

                    onCurrentValueChanged: assetView.sortByValue(currentValue)
                }
            }
        }
    }

    Settings {
        property alias loading: loadingCheckBox.checked
        property alias filterVisible: sorterVisibleCheckBox.checked
        property alias customOrderAvailable: customOrderAvailableCheckBox.checked
        property alias sendEnabled: sendEnabledCheckBox.checked
        property alias swapEnabled: swapEnabledCheckBox.checked
        property alias swapVisible: swapVisibleCheckBox.checked
        property alias balanceError: balanceErrorCheckBox.checked
        property alias marketDataError: marketDataErrorCheckBox.checked
    }
}

// category: Views
// status: good

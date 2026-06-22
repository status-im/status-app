import QtQuick
import QtTest

import shared.views
import utils


Item {
    id: root
    width: 600
    height: 900

    readonly property var orderBalanceAsc: [
        "Dai Stablecoin", "Status Test Token", "Wrapped Ether", "Ether"
    ]
    readonly property var orderBalanceDesc: [
        "Ether", "Wrapped Ether", "Status Test Token", "Dai Stablecoin"
    ]
    readonly property var orderPriceAsc: [
        "Status Test Token", "Dai Stablecoin", "Wrapped Ether", "Ether"
    ]
    readonly property var orderPriceDesc: [
        "Ether", "Wrapped Ether", "Dai Stablecoin", "Status Test Token"
    ]
    readonly property var orderNameAsc: [
        "Dai Stablecoin", "Ether", "Status Test Token", "Wrapped Ether"
    ]
    readonly property var orderNameDesc: [
        "Wrapped Ether", "Status Test Token", "Ether", "Dai Stablecoin"
    ]

    ListModel {
        id: assetsModel

        function formatBalance(amount, symbol) {
            return amount.toLocaleCurrencyString(Qt.locale(), symbol)
        }

        Component.onCompleted: {
            append([
                {
                    key: "key_DAI",
                    symbol: "DAI",
                    name: "Dai Stablecoin",
                    logoUri: Constants.tokenIcon("DAI", false),
                    balance: 1.0,
                    balanceText: formatBalance(1.0, "DAI"),
                    balanceLoading: false,
                    error: "",
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.0,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
                    position: 1,
                    canBeHidden: true
                },
                {
                    key: "key_STT",
                    symbol: "STT",
                    name: "Status Test Token",
                    logoUri: Constants.tokenIcon("STT", false),
                    balance: 2.0,
                    balanceText: formatBalance(2.0, "STT"),
                    balanceLoading: false,
                    error: "",
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 2.0,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
                    position: 2,
                    canBeHidden: true
                },
                {
                    key: "key_WETH",
                    symbol: "WETH",
                    name: "Wrapped Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 3.0,
                    balanceText: formatBalance(3.0, "WETH"),
                    balanceLoading: false,
                    error: "",
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.1,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
                    position: 3,
                    canBeHidden: true
                },
                {
                    key: "key_ETH",
                    symbol: "ETH",
                    name: "Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 4.0,
                    balanceText: formatBalance(4.0, "ETH"),
                    balanceLoading: false,
                    error: "",
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 4.1,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
                    position: 4,
                    canBeHidden: false
                }
            ])
        }
    }

    Component {
        id: assetsViewComponent
        AssetsView {
            width: root.width
            height: root.height
            sorterVisible: true
            model: assetsModel
        }
    }

    TestCase {
        id: assetsViewTest
        name: "AssetsView"
        when: windowShown

        property AssetsView controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(assetsViewComponent, root)
            waitForRendering(controlUnderTest)
        }

        function getListView(assetView) {
            const listView = findChild(assetView, "assetViewStatusListView")
            verify(!!listView)
            return listView
        }

        function getSortComboBox() {
            const comboBox = findChild(controlUnderTest, "cmbTokenOrder")
            verify(!!comboBox)
            return comboBox
        }

        function verifyAssetOrder(expectedTitles) {
            const listView = getListView(controlUnderTest)
            waitForRendering(listView)
            compare(listView.count, expectedTitles.length)
            for (let i = 0; i < expectedTitles.length; ++i)
                compare(listView.itemAtIndex(i).title, expectedTitles[i])
        }

        function verifyComboBoxDisplay(comboBox, optionText, ascending) {
            const suffix = ascending ? " ↑" : " ↓"
            compare(comboBox.displayText, optionText + suffix)
        }

        function openSortPopup(comboBox) {
            mouseClick(comboBox)
            tryVerify(() => comboBox.popup.opened)
            waitForRendering(comboBox.popup.contentItem)
        }

        function applySortOption(comboBox, optionText, ascending) {
            openSortPopup(comboBox)

            let index = -1
            for (let i = 0; i < comboBox.count; ++i) {
                if (comboBox.model[i].text === optionText) {
                    index = i
                    break
                }
            }
            verify(index !== -1, "Sort option not found: " + optionText)

            const listView = findChild(comboBox.popup.contentItem, "sortOrderListView")
            const delegate = listView.itemAtIndex(index)
            mouseMove(delegate, delegate.width / 2, delegate.height / 2)
            mouseClick(findChild(delegate, ascending ? "sortArrowUp" : "sortArrowDown"))

            tryVerify(() => !comboBox.popup.opened)
            waitForRendering(controlUnderTest)
        }

        function verifySortByUi(optionText, orderAsc, orderDesc) {
            const comboBox = getSortComboBox()
            applySortOption(comboBox, optionText, true)
            verifyComboBoxDisplay(comboBox, optionText, true)
            verifyAssetOrder(orderAsc)

            applySortOption(comboBox, optionText, false)
            verifyComboBoxDisplay(comboBox, optionText, false)
            verifyAssetOrder(orderDesc)
        }

        function test_sortByUi_asc_desc_data() {
            return [
                { tag: "balanceValue", optionText: "Asset balance value",
                    orderAsc: orderBalanceAsc, orderDesc: orderBalanceDesc },
                { tag: "balance", optionText: "Asset balance",
                    orderAsc: orderBalanceAsc, orderDesc: orderBalanceDesc },
                { tag: "assetValue", optionText: "Asset value",
                    orderAsc: orderPriceAsc, orderDesc: orderPriceDesc },
                { tag: "1dChange", optionText: "1d change: balance value",
                    orderAsc: orderBalanceAsc, orderDesc: orderBalanceDesc },
                { tag: "assetName", optionText: "Asset name",
                    orderAsc: orderNameAsc, orderDesc: orderNameDesc },
            ]
        }

        function test_sortByUi_asc_desc(data) {
            verifySortByUi(data.optionText, data.orderAsc, data.orderDesc)
        }
    }
}

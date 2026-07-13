import QtQuick
import QtTest

import shared.views
import utils

import StatusQ
import SortFilterProxyModel


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
            append([
                {
                    key: "key_DAI",
                    symbol: "DAI",
                    name: "Dai Stablecoin",
                    logoUri: Constants.tokenIcon("DAI", false),
                    balance: 1.0,
                    balanceLoading: false,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.0,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),
                    position: 1,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_STT",
                    symbol: "STT",
                    name: "Status Test Token",
                    logoUri: Constants.tokenIcon("STT", false),
                    balance: 2.0,
                    balanceLoading: false,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 2.0,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),
                    position: 2,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_WETH",
                    symbol: "WETH",
                    name: "Wrapped Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 3.0,
                    balanceLoading: false,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.1,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),
                    position: 3,
                    canBeHidden: true,
                    visible: true,
                    chainIds: "1"
                },
                {
                    key: "key_ETH",
                    symbol: "ETH",
                    name: "Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 4.0,
                    balanceLoading: false,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 4.1,
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityImage: Qt.resolvedUrl(""),
                    position: 4,
                    canBeHidden: false,
                    visible: true,
                    chainIds: "1"
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
            onSortRequested: (roleName, order) => assetsModel.sortBy(roleName, order)
        }
    }

    // A source model that starts empty; rows are appended during the test to
    // reproduce the production timing where token rows arrive asynchronously,
    // after the view is already up in its `loading` state.
    ListModel {
        id: asyncBaseModel
    }

    SortFilterProxyModel {
        id: asyncAssetsModel

        property int sortRoleOrder: Qt.DescendingOrder
        property string sortRoleName: "name"

        function sortBy(roleName, order) {
            asyncAssetsModel.sortRoleName = roleName
            asyncAssetsModel.sortRoleOrder = order
        }

        sourceModel: asyncBaseModel
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
                roleName: asyncAssetsModel.sortRoleName
                sortOrder: asyncAssetsModel.sortRoleOrder
            }
        ]
    }

    Component {
        id: asyncAssetsViewComponent
        AssetsView {
            width: root.width
            height: root.height
            sorterVisible: true
            model: asyncAssetsModel
            onSortRequested: (roleName, order) => asyncAssetsModel.sortBy(roleName, order)
        }
    }

    Component {
        id: modelChangedSpyComponent
        SignalSpy { signalName: "modelChanged" }
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

        // A periodic market/balance refresh toggles `loading` while real data is
        // already present. Once the regular model has content the list must stay
        // bound to it — swapping to the loading placeholder tears down and
        // recreates every delegate on each refresh.
        function test_loadingToggle_keepsPopulatedModel() {
            const listView = getListView(controlUnderTest)
            waitForRendering(listView)
            compare(listView.count, 4)
            const modelInstance = listView.model

            controlUnderTest.loading = true
            verify(listView.model === modelInstance,
                "loading placeholder must not replace the populated model on refresh")
            compare(listView.count, 4)

            controlUnderTest.loading = false
            verify(listView.model === modelInstance)
            compare(listView.count, 4)
        }

        // Once data is present, toggling `loading` must not re-assign the list's
        // model at all. Keeping the same model instance is not enough: on the
        // production ListView, re-assigning even the identical DelegateModel makes
        // the view rebuild every delegate. The model binding must therefore drop
        // `loading` from its dependencies once the content latch is set, so the
        // periodic refresh toggles never re-evaluate it.
        function test_loadingToggle_doesNotReassignModel() {
            const listView = getListView(controlUnderTest)
            waitForRendering(listView)
            compare(listView.count, 4)   // regular model, data present

            const spy = modelChangedSpyComponent.createObject(root, { target: listView })
            verify(spy.valid)
            spy.clear()

            for (let i = 0; i < 4; ++i) {
                controlUnderTest.loading = (i % 2 === 0)
                waitForRendering(listView)
            }

            compare(spy.count, 0,
                "loading toggles must not re-assign the list model once data is present")
            spy.destroy()
        }

        // Covers the production initial condition the sort test above does not:
        // the view starts in the global `loading` state (list on the placeholder)
        // and token rows arrive asynchronously afterwards. Once real data has
        // arrived the list must switch to and stay on the regular model across
        // the periodic `loading` toggles, never rebuilding against the
        // placeholder. NOTE: the on-device regression this guards is driven by
        // the C++ terminal model not reporting its rows until a view consumes
        // the regular DelegateModel; QML ListModel/SortFilterProxyModel report
        // rows eagerly, so this case cannot fully reproduce that timing here —
        // the authoritative red/green for it is the on-device startup trace.
        function test_loadingStartTrue_latchesFromSourceModel() {
            asyncBaseModel.clear()
            const view = createTemporaryObject(asyncAssetsViewComponent, root,
                { loading: true })
            verify(!!view)
            const listView = getListView(view)
            waitForRendering(listView)

            // Rows arrive while still loading and while the list is on the
            // placeholder (the regular DelegateModel is not consumed yet).
            asyncBaseModel.append({
                key: "key_ETH", symbol: "ETH", name: "Ether",
                logoUri: Constants.tokenIcon("ETH", false),
                balance: 4.0, balanceLoading: false,
                marketDetailsAvailable: true, marketDetailsLoading: false,
                marketPrice: 4.1, marketChangePct24hour: 5.0,
                communityId: "", communityName: "",
                communityImage: Qt.resolvedUrl(""),
                position: 1, canBeHidden: false, visible: true, chainIds: "1"
            })
            waitForRendering(listView)

            // First real data has arrived: switch to the regular model and stay
            // there across the periodic loading toggle.
            view.loading = false
            waitForRendering(listView)
            const populatedModel = listView.model
            compare(listView.count, 1)

            view.loading = true
            verify(listView.model === populatedModel,
                "loading placeholder must not replace the populated model after first data")
            compare(listView.count, 1)

            view.loading = false
            verify(listView.model === populatedModel)
            compare(listView.count, 1)
        }
    }
}

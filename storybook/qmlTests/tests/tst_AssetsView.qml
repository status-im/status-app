import QtCore
import QtQuick
import QtTest

import StatusQ
import StatusQ.Models

import shared.views
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.controls
import utils
import QtModelsToolkit
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

    ListModel {
        id: assetsModel

        function formatBalance(amount, symbol) {
            return amount.toLocaleCurrencyString(Qt.locale(), symbol)
        }

        function marketDetailsForPrice(price) {
            return {
                currencyPrice: {
                    amount: price,
                    displayDecimals: 2,
                    stripTrailingZeroes: false,
                    symbol: "USD"
                }
            }
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
                    decimals: 18,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.0,
                    marketDetails: marketDetailsForPrice(3.0),
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
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
                    decimals: 18,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 2.0,
                    marketDetails: marketDetailsForPrice(2.0),
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
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
                    decimals: 18,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 3.1,
                    marketDetails: marketDetailsForPrice(3.1),
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
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
                    decimals: 18,
                    marketDetailsAvailable: true,
                    marketDetailsLoading: false,
                    marketPrice: 4.1,
                    marketDetails: marketDetailsForPrice(4.1),
                    marketChangePct24hour: 5.0,
                    communityId: "",
                    communityName: "",
                    communityIcon: Qt.resolvedUrl(""),
                    canBeHidden: false
                }
            ])
        }
    }

    QtObject {
        id: customOrderSettingsStore
        property var jsonData: null
        function setValue(_key, value) { jsonData = value }
        function value(_key, defaultValue) { return jsonData !== null ? jsonData : defaultValue }
    }

    QtObject {
        id: walletSettingsStore
        property var assetsViewCustomOrderApplyTimestamp: 0
    }

    QtObject {
        id: assetsSortSettingsStore
        property int currentSortValue: SortOrderComboBox.TokenOrderBalance
        property var sortOrderUpdateTimestamp: 0
        property int currentSortOrder: Qt.DescendingOrder
    }

    ManageTokensController {
        id: assetsController
        sourceModel: assetsModel
        settingsKey: "AssetsViewCustomOrderTest"
        serializeAsCollectibles: false

        onRequestSaveSettings: (jsonData) => {
            savingStarted()
            customOrderSettingsStore.setValue(settingsKey, jsonData)
            savingFinished()
        }
        onRequestLoadSettings: {
            loadingStarted()
            loadingFinished(customOrderSettingsStore.value(settingsKey, null))
        }
        onRequestClearSettings: customOrderSettingsStore.setValue(settingsKey, null)
    }

    SortFilterProxyModel {
        id: assetsViewModel
        sourceModel: assetsModel
        proxyRoles: [
            FastExpressionRole {
                name: "position"
                expression: {
                    assetsController.revision
                    return assetsController.order(model.key)
                }
                expectedRoles: ["key"]
            }
        ]
    }

    QtObject {
        id: flowState
        // settings | manageTokens | wallet
        property string screen: "settings"
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

    Component {
        id: customOrderingHarnessComponent
        Item {
            width: root.width
            height: root.height

            property alias assetsView: assetsView
            property alias managePanel: managePanel

            AssetsView {
                id: assetsView
                anchors.fill: parent
                sorterVisible: true
                model: assetsViewModel
                customOrderAvailable: assetsController.hasSettings
                onManageTokensRequested: flowState.screen = "manageTokens"

                function refreshSortSettings() {
                    let value = SortOrderComboBox.TokenOrderBalance
                    let order = assetsSortSettingsStore.currentSortOrder
                    if (walletSettingsStore.assetsViewCustomOrderApplyTimestamp > assetsSortSettingsStore.sortOrderUpdateTimestamp
                            && customOrderAvailable) {
                        value = SortOrderComboBox.TokenOrderCustom
                        order = Qt.AscendingOrder
                    } else {
                        value = assetsSortSettingsStore.currentSortValue
                    }
                    sortByValue(value)
                    setSortOrder(order)
                }

                Component.onCompleted: refreshSortSettings()

                Connections {
                    target: walletSettingsStore
                    function onAssetsViewCustomOrderApplyTimestampChanged() {
                        assetsView.refreshSortSettings()
                    }
                }
            }

            ManageAssetsPanel {
                id: managePanel
                z: 1
                anchors.fill: parent
                visible: flowState.screen === "manageTokens"
                controller: assetsController
                getCurrencyAmount: function (balance, symbol) {
                    return ({
                        amount: balance,
                        symbol: symbol,
                        displayDecimals: 2,
                        stripTrailingZeroes: false
                    })
                }
                getCurrentCurrencyAmount: function (balance) {
                    return ({
                        amount: balance,
                        symbol: "USD",
                        displayDecimals: 2,
                        stripTrailingZeroes: false
                    })
                }
            }
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

    TestCase {
        name: "AssetsViewCustomOrdering"
        when: windowShown

        property Item harness: null

        function init() {
            flowState.screen = "settings"
            assetsController.requestClearSettings()
            customOrderSettingsStore.setValue("AssetsViewCustomOrderTest", null)
            walletSettingsStore.assetsViewCustomOrderApplyTimestamp = 0
            assetsSortSettingsStore.currentSortValue = SortOrderComboBox.TokenOrderBalance
            assetsSortSettingsStore.sortOrderUpdateTimestamp = 0
            assetsSortSettingsStore.currentSortOrder = Qt.DescendingOrder
            harness = createTemporaryObject(customOrderingHarnessComponent, root)
            waitForRendering(harness)
        }

        function cleanup() {
            flowState.screen = "settings"
            if (harness)
                harness.destroy()
            harness = null
            assetsController.requestClearSettings()
            customOrderSettingsStore.setValue("AssetsViewCustomOrderTest", null)
            walletSettingsStore.assetsViewCustomOrderApplyTimestamp = 0
            assetsSortSettingsStore.currentSortValue = SortOrderComboBox.TokenOrderBalance
            assetsSortSettingsStore.sortOrderUpdateTimestamp = 0
            assetsSortSettingsStore.currentSortOrder = Qt.DescendingOrder
        }

        function getView(screen) {
            tryVerify(() => flowState.screen === screen)
            if (screen === "manageTokens")
                return harness.managePanel
            verify(!!findChild(harness.assetsView, "cmbTokenOrder"))
            return harness.assetsView
        }

        function getListView(assetView) {
            const listView = findChild(assetView, "assetViewStatusListView")
            verify(!!listView)
            return listView
        }

        function getSortComboBox(assetView) {
            const comboBox = findChild(assetView, "cmbTokenOrder")
            verify(!!comboBox)
            return comboBox
        }

        function openSortPopup(comboBox) {
            mouseClick(comboBox)
            tryVerify(() => comboBox.popup.opened)
            waitForRendering(comboBox.popup.contentItem)
        }

        function clickSortMenuItem(comboBox, optionText) {
            let index = -1
            tryVerify(() => {
                for (let i = 0; i < comboBox.count; ++i) {
                    if (comboBox.textAt(i) === optionText) {
                        index = i
                        return true
                    }
                }
                return false
            })
            verify(index !== -1, "Sort option not found: " + optionText)

            openSortPopup(comboBox)

            const listView = findChild(comboBox.popup.contentItem, "sortOrderListView")
            const delegate = listView.itemAtIndex(index)
            mouseClick(delegate, delegate.width / 2, delegate.height / 2)

            tryVerify(() => !comboBox.popup.opened)
            waitForRendering(harness)
        }

        function verifyCustomOrderApplied(assetView, expectedTitles) {
            const listView = getListView(assetView)
            waitForRendering(listView)
            tryVerify(() => {
                if (getSortComboBox(assetView).displayText !== "Custom order")
                    return false
                if (listView.count !== expectedTitles.length)
                    return false
                for (let i = 0; i < expectedTitles.length; ++i) {
                    const item = listView.itemAtIndex(i)
                    if (!item || item.title !== expectedTitles[i])
                        return false
                }
                return true
            })
        }

        function applyCustomOrderToWallet() {
            // WalletView.onSaveChangesClicked — timestamp only, no explicit refresh
            walletSettingsStore.assetsViewCustomOrderApplyTimestamp = new Date().getTime()
            flowState.screen = "wallet"
            waitForRendering(harness)
            waitForRendering(harness.assetsView)
            return harness.assetsView
        }

        function findDelegateIndexWithTitle(managePanel, title) {
            const count = assetsController.regularTokensModel.count
            for (let i = 0; i < count; ++i) {
                const delegate = findChild(managePanel, "manageTokensDelegate-%1".arg(i))
                if (!!delegate && delegate.title === title)
                    return i
            }
            return -1
        }

        function triggerDelegateMenuAction(managePanel, index, actionName) {
            const token = findChild(managePanel, "manageTokensDelegate-%1".arg(index))
            verify(!!token)
            const delegateBtn = findChild(token, "btnManageTokenMenu-%1".arg(index))
            verify(!!delegateBtn)

            waitForItemPolished(delegateBtn)
            mouseClick(delegateBtn)
            const btnMenuLoader = findChild(delegateBtn, "manageTokensContextMenuLoader")
            verify(!!btnMenuLoader)

            tryCompare(btnMenuLoader, "active", true)
            const btnMenu = btnMenuLoader.item
            verify(!!btnMenu)
            verify(btnMenu.open)
            const action = findChild(btnMenu, actionName)
            verify(!!action)
            action.trigger()
        }

        function test_customOrdering_fullFlow() {
            const assetsView = getView("settings")
            const comboBox = getSortComboBox(assetsView)

            clickSortMenuItem(comboBox, "Create custom order →")
            tryVerify(() => flowState.screen === "manageTokens")

            const managePanel = getView("manageTokens")
            const delegate0 = findChild(managePanel, "manageTokensDelegate-0")
            verify(!!delegate0)
            compare(delegate0.title, "Dai Stablecoin")

            triggerDelegateMenuAction(managePanel, 0, "miMoveToBottom")

            verify(managePanel.dirty)
            managePanel.saveSettings(false /* update */)
            verify(!managePanel.dirty)
            verify(assetsController.hasSettings)

            flowState.screen = "wallet"
            waitForRendering(harness)

            clickSortMenuItem(getSortComboBox(getView("wallet")), "Edit custom order →")
            tryVerify(() => flowState.screen === "manageTokens")

            const managePanelEdit = getView("manageTokens")
            const ethIndex = findDelegateIndexWithTitle(managePanelEdit, "Ether")
            verify(ethIndex !== -1)
            triggerDelegateMenuAction(managePanelEdit, ethIndex, "miMoveToBottom")

            managePanelEdit.saveSettings(true /* update */)
            verify(!managePanelEdit.dirty)
            waitForRendering(harness)

            const walletAssetsView = applyCustomOrderToWallet()
            verifyCustomOrderApplied(walletAssetsView, [
                "Status Test Token", "Wrapped Ether", "Dai Stablecoin", "Ether"
            ])
        }
    }
}

import QtCore
import QtQuick
import QtTest

import StatusQ.Models

import AppLayouts.Wallet.views
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.controls
import Models
import utils
import QtModelsToolkit

Item {
    id: root
    width: 600
    height: 1200

    readonly property string testAccount: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"

    readonly property var communityNameAsc: ["Comm Alpha", "Comm Beta"]
    readonly property var communityNameDesc: ["Comm Beta", "Comm Alpha"]
    readonly property var communityGroupAsc: ["Comm Alpha", "Comm Beta"]
    readonly property var communityGroupDesc: ["Comm Beta", "Comm Alpha"]
    readonly property var communityDateAsc: ["Comm Alpha", "Comm Beta"]
    readonly property var communityDateDesc: ["Comm Beta", "Comm Alpha"]

    readonly property var regularNameAsc: ["Reg Charlie", "Reg Delta"]
    readonly property var regularNameDesc: ["Reg Delta", "Reg Charlie"]
    readonly property var regularGroupAsc: ["Reg Charlie", "Reg Delta"]
    readonly property var regularGroupDesc: ["Reg Delta", "Reg Charlie"]
    readonly property var regularDateAsc: ["Reg Charlie", "Reg Delta"]
    readonly property var regularDateDesc: ["Reg Delta", "Reg Charlie"]

    ListModel {
        id: collectiblesModel

        Component.onCompleted: {
            append([
                {
                    uid: "comm_alpha",
                    symbol: "comm_alpha",
                    chainId: 1,
                    name: "Comm Alpha",
                    collectionUid: "",
                    collectionName: "",
                    communityId: "alpha_comm",
                    communityName: "Alpha Community",
                    communityImage: "",
                    imageUrl: "",
                    isLoading: false,
                    backgroundColor: "",
                    ownership: [{
                        accountAddress: root.testAccount,
                        balance: "1",
                        txTimestamp: 100
                    }],
                    tokenId: "1"
                },
                {
                    uid: "comm_beta",
                    symbol: "comm_beta",
                    chainId: 1,
                    name: "Comm Beta",
                    collectionUid: "",
                    collectionName: "",
                    communityId: "zeta_comm",
                    communityName: "Zeta Community",
                    communityImage: "",
                    imageUrl: "",
                    isLoading: false,
                    backgroundColor: "",
                    ownership: [{
                        accountAddress: root.testAccount,
                        balance: "1",
                        txTimestamp: 200
                    }],
                    tokenId: "2"
                },
                {
                    uid: "reg_charlie",
                    symbol: "reg_charlie",
                    chainId: 1,
                    name: "Reg Charlie",
                    collectionUid: "charlie_col",
                    collectionName: "Charlie Collection",
                    communityId: "",
                    communityName: "",
                    communityImage: "",
                    imageUrl: "",
                    isLoading: false,
                    backgroundColor: "",
                    ownership: [{
                        accountAddress: root.testAccount,
                        balance: "1",
                        txTimestamp: 300
                    }],
                    tokenId: "3"
                },
                {
                    uid: "reg_delta",
                    symbol: "reg_delta",
                    chainId: 1,
                    name: "Reg Delta",
                    collectionUid: "delta_col",
                    collectionName: "Delta Collection",
                    communityId: "",
                    communityName: "",
                    communityImage: "",
                    imageUrl: "",
                    isLoading: false,
                    backgroundColor: "",
                    ownership: [{
                        accountAddress: root.testAccount,
                        balance: "1",
                        txTimestamp: 400
                    }],
                    tokenId: "4"
                }
            ])
        }
    }

    RolesRenamingModel {
        id: renamedModel
        sourceModel: collectiblesModel
        mapping: [
            RoleRename {
                from: "uid"
                to: "key"
            }
        ]
    }

    Settings {
        id: settingsStore
        category: "CollectiblesViewTest"
    }

    QtObject {
        id: customOrderSettingsStore
        property var jsonData: null
        function setValue(_key, value) { jsonData = value }
        function value(_key, defaultValue) { return jsonData !== null ? jsonData : defaultValue }
    }

    QtObject {
        id: walletSettingsStore
        property var collectiblesViewCustomOrderApplyTimestamp: 0
    }

    QtObject {
        id: collectiblesSortSettingsStore
        property int currentSortValue: SortOrderComboBox.TokenOrderDateAdded
        property var sortOrderUpdateTimestamp: 0
        property int currentSortOrder: Qt.AscendingOrder
    }

    Component {
        id: collectiblesViewComponent
        CollectiblesView {
            width: root.width
            height: root.height
            filterVisible: true
            customOrderAvailable: false
            ownedAccountsModel: WalletAccountsModel {}
            activeNetworks: NetworksModel.flatNetworks
            addressFilters: root.testAccount
            networkFilters: "1"
            unsupportedChainIds: []
            controller: ManageTokensController {
                sourceModel: renamedModel
                settingsKey: "CollectiblesViewTest"
                serializeAsCollectibles: true

                onRequestSaveSettings: (jsonData) => {
                    savingStarted()
                    settingsStore.setValue(settingsKey, jsonData)
                    savingFinished()
                }
                onRequestLoadSettings: {
                    loadingStarted()
                    loadingFinished(settingsStore.value(settingsKey, null))
                }
                onRequestClearSettings: settingsStore.setValue(settingsKey, null)
            }
        }
    }

    ManageTokensController {
        id: customOrderController
        sourceModel: renamedModel
        settingsKey: "CollectiblesViewCustomOrderTest"
        serializeAsCollectibles: true

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

    QtObject {
        id: flowState
        // settings | manageTokens | wallet
        property string screen: "settings"
    }

    Component {
        id: customOrderingHarnessComponent
        Item {
            width: root.width
            height: root.height

            property alias collectiblesView: collectiblesView
            property alias managePanel: managePanel

            CollectiblesView {
                id: collectiblesView
                anchors.fill: parent
                filterVisible: true
                customOrderAvailable: customOrderController.hasSettings
                ownedAccountsModel: WalletAccountsModel {}
                activeNetworks: NetworksModel.flatNetworks
                addressFilters: root.testAccount
                networkFilters: "1"
                unsupportedChainIds: []
                controller: customOrderController
                onManageTokensRequested: flowState.screen = "manageTokens"

                function refreshSortSettings() {
                    let value = SortOrderComboBox.TokenOrderDateAdded
                    let order = collectiblesSortSettingsStore.currentSortOrder
                    if (walletSettingsStore.collectiblesViewCustomOrderApplyTimestamp > collectiblesSortSettingsStore.sortOrderUpdateTimestamp
                            && customOrderAvailable) {
                        value = SortOrderComboBox.TokenOrderCustom
                        order = Qt.AscendingOrder
                    } else {
                        value = collectiblesSortSettingsStore.currentSortValue
                    }
                    sortByValue(value)
                    setSortOrder(order)
                }

                Component.onCompleted: refreshSortSettings()

                Connections {
                    target: walletSettingsStore
                    function onCollectiblesViewCustomOrderApplyTimestampChanged() {
                        collectiblesView.refreshSortSettings()
                    }
                }
            }

            ManageCollectiblesPanel {
                id: managePanel
                z: 1
                anchors.fill: parent
                visible: flowState.screen === "manageTokens"
                controller: customOrderController
            }
        }
    }

    TestCase {
        name: "CollectiblesView"
        when: windowShown

        property CollectiblesView controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(collectiblesViewComponent, root)
            waitForRendering(controlUnderTest)
        }

        function getSortComboBox() {
            const comboBox = findChild(controlUnderTest, "cmbTokenOrder")
            verify(!!comboBox)
            return comboBox
        }

        function verifyGridOrder(gridObjectName, expectedTitles) {
            const grid = findChild(controlUnderTest, gridObjectName)
            verify(!!grid)
            waitForRendering(grid)
            compare(grid.count, expectedTitles.length)
            for (let i = 0; i < expectedTitles.length; ++i)
                compare(grid.itemAtIndex(i).title, expectedTitles[i])
        }

        function verifyCollectiblesOrder(communityTitles, regularTitles) {
            verifyGridOrder("communityCollectiblesView", communityTitles)
            verifyGridOrder("regularCollectiblesView", regularTitles)
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

        function verifySortByUi(optionText, communityAsc, communityDesc, regularAsc, regularDesc) {
            const comboBox = getSortComboBox()
            applySortOption(comboBox, optionText, true)
            verifyComboBoxDisplay(comboBox, optionText, true)
            verifyCollectiblesOrder(communityAsc, regularAsc)

            applySortOption(comboBox, optionText, false)
            verifyComboBoxDisplay(comboBox, optionText, false)
            verifyCollectiblesOrder(communityDesc, regularDesc)
        }

        function test_sortByUi_asc_desc_data() {
            return [
                { tag: "name", optionText: "Collectible name",
                    communityAsc: communityNameAsc, communityDesc: communityNameDesc,
                    regularAsc: regularNameAsc, regularDesc: regularNameDesc },
                { tag: "groupName", optionText: "Collection/community name",
                    communityAsc: communityGroupAsc, communityDesc: communityGroupDesc,
                    regularAsc: regularGroupAsc, regularDesc: regularGroupDesc },
                { tag: "dateAdded", optionText: "Date added",
                    communityAsc: communityDateAsc, communityDesc: communityDateDesc,
                    regularAsc: regularDateAsc, regularDesc: regularDateDesc },
            ]
        }

        function test_sortByUi_asc_desc(data) {
            verifySortByUi(data.optionText, data.communityAsc, data.communityDesc,
                           data.regularAsc, data.regularDesc)
        }
    }

    TestCase {
        name: "CollectiblesViewCustomOrdering"
        when: windowShown

        property Item harness: null

        function init() {
            flowState.screen = "settings"
            customOrderController.requestClearSettings()
            customOrderSettingsStore.setValue("CollectiblesViewCustomOrderTest", null)
            walletSettingsStore.collectiblesViewCustomOrderApplyTimestamp = 0
            collectiblesSortSettingsStore.currentSortValue = SortOrderComboBox.TokenOrderDateAdded
            collectiblesSortSettingsStore.sortOrderUpdateTimestamp = 0
            collectiblesSortSettingsStore.currentSortOrder = Qt.AscendingOrder
            harness = createTemporaryObject(customOrderingHarnessComponent, root)
            waitForRendering(harness)
        }

        function cleanup() {
            flowState.screen = "settings"
            if (harness)
                harness.destroy()
            harness = null
            customOrderController.requestClearSettings()
            customOrderSettingsStore.setValue("CollectiblesViewCustomOrderTest", null)
            walletSettingsStore.collectiblesViewCustomOrderApplyTimestamp = 0
            collectiblesSortSettingsStore.currentSortValue = SortOrderComboBox.TokenOrderDateAdded
            collectiblesSortSettingsStore.sortOrderUpdateTimestamp = 0
            collectiblesSortSettingsStore.currentSortOrder = Qt.AscendingOrder
        }

        function getView(screen) {
            tryVerify(() => flowState.screen === screen)
            if (screen === "manageTokens")
                return harness.managePanel
            verify(!!findChild(harness.collectiblesView, "cmbTokenOrder"))
            return harness.collectiblesView
        }

        function getSortComboBox(collectiblesView) {
            const comboBox = findChild(collectiblesView, "cmbTokenOrder")
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

        function verifyCustomOrderApplied(collectiblesView, gridObjectName, expectedTitles) {
            const grid = findChild(collectiblesView, gridObjectName)
            verify(!!grid)
            waitForRendering(grid)
            tryVerify(() => {
                if (getSortComboBox(collectiblesView).displayText !== "Custom order")
                    return false
                if (grid.count !== expectedTitles.length)
                    return false
                for (let i = 0; i < expectedTitles.length; ++i) {
                    const item = grid.itemAtIndex(i)
                    if (!item || item.title !== expectedTitles[i])
                        return false
                }
                return true
            })
        }

        function applyCustomOrderToWallet() {
            // WalletView.onSaveChangesClicked — timestamp only, no explicit refresh
            walletSettingsStore.collectiblesViewCustomOrderApplyTimestamp = new Date().getTime()
            flowState.screen = "wallet"
            waitForRendering(harness)
            waitForRendering(harness.collectiblesView)
            return harness.collectiblesView
        }

        function test_customOrdering_fullFlow() {
            const collectiblesView = getView("settings")
            clickSortMenuItem(getSortComboBox(collectiblesView), "Create custom order →")
            tryVerify(() => flowState.screen === "manageTokens")

            const managePanel = getView("manageTokens")
            const lvOther = findChild(managePanel, "otherTokensListView")
            verify(!!lvOther)
            tryCompare(lvOther, "count", 2)

            const delegate0 = findChild(lvOther, "manageTokensDelegate-0")
            verify(!!delegate0)
            compare(delegate0.title, "Reg Charlie")
            waitForRendering(delegate0)
            mouseDrag(delegate0, delegate0.width / 2, delegate0.height / 2, 0, delegate0.height)

            verify(managePanel.dirty)
            managePanel.saveSettings(false /* update */)
            verify(!managePanel.dirty)
            verify(customOrderController.hasSettings)

            flowState.screen = "wallet"
            waitForRendering(harness)

            clickSortMenuItem(getSortComboBox(getView("wallet")), "Edit custom order →")
            tryVerify(() => flowState.screen === "manageTokens")

            const managePanelEdit = getView("manageTokens")
            const lvOtherEdit = findChild(managePanelEdit, "otherTokensListView")
            verify(!!lvOtherEdit)
            const charlieDelegate = findChild(lvOtherEdit, "manageTokensDelegate-1")
            verify(!!charlieDelegate)
            compare(charlieDelegate.title, "Reg Charlie")
            waitForRendering(charlieDelegate)
            mouseDrag(charlieDelegate, charlieDelegate.width / 2, charlieDelegate.height / 2,
                      0, -charlieDelegate.height)

            managePanelEdit.saveSettings(true /* update */)
            verify(!managePanelEdit.dirty)
            waitForRendering(harness)

            const walletCollectiblesView = applyCustomOrderToWallet()
            verifyCustomOrderApplied(walletCollectiblesView, "regularCollectiblesView",
                                    ["Reg Charlie", "Reg Delta"])
        }
    }
}

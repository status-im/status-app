import QtCore
import QtQuick
import QtTest

import StatusQ.Models

import AppLayouts.Wallet.views
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
}

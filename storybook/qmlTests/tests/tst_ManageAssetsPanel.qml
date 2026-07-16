import QtCore
import QtQuick
import QtTest

import StatusQ.Models

import AppLayouts.Wallet.panels

import utils

Item {
    id: root
    width: 600
    height: 2000

    ListModel {
        id: assetsModel

        Component.onCompleted: {
            append([
                {
                    key: "key_DAI",
                    symbol: "DAI",
                    name: "Dai Stablecoin",
                    logoUri: Constants.tokenIcon("DAI", false),
                    balance: 1.0,
                    communityId: "",
                    communityName: "",
                    position: 1
                },
                {
                    key: "key_STT",
                    symbol: "STT",
                    name: "Status Test Token",
                    logoUri: Constants.tokenIcon("STT", false),
                    balance: 2.0,
                    communityId: "",
                    communityName: "",
                    position: 2
                },
                {
                    key: "key_WETH",
                    symbol: "WETH",
                    name: "Wrapped Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 3.0,
                    communityId: "",
                    communityName: "",
                    position: 3
                },
                {
                    key: "key_ETH",
                    symbol: "ETH",
                    name: "Ether",
                    logoUri: Constants.tokenIcon("ETH", false),
                    balance: 4.0,
                    communityId: "",
                    communityName: "",
                    position: 4
                }
            ])
        }
    }

    Component {
        id: componentUnderTest
        ManageAssetsPanel {
            id: panel
            width: 500
            height: contentHeight

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

            controller: ManageTokensController {
                sourceModel: assetsModel
                settingsKey: "WalletAssets"
                serializeAsCollectibles: false

                onRequestSaveSettings: (jsonData) => {
                    savingStarted()
                    settingsStore.setValue(settingsKey, jsonData)
                    savingFinished()
                }
                onRequestLoadSettings: {
                    loadingStarted()
                    const jsonData = settingsStore.value(settingsKey, null)
                    loadingFinished(jsonData)
                }
                onRequestClearSettings: panel.clearSettings()
            }

            function clearSettings() {
                controller.clearQSettings()
                settingsStore.setValue(panel.controller.settingsKey, null)
            }

            Settings {
                id: settingsStore
                category: "ManageTokens-" + panel.controller.settingsKey
            }
        }
    }

    TestCase {
        name: "ManageAssetsPanel"
        when: windowShown

        property ManageAssetsPanel controlUnderTest: null

        function findDelegateMenuAction(index, actionName) {
            const token = findChild(controlUnderTest, "manageTokensDelegate-%1".arg(index))
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
            return findChild(btnMenu, actionName)
        }

        function triggerDelegateMenuAction(index, actionName) {
            const action = findDelegateMenuAction(index, actionName)
            verify(!!action)
            action.trigger()
        }

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            controlUnderTest.clearSettings()
        }

        function test_persistCustomOrderOnSave() {
            verify(!controlUnderTest.dirty)
            waitForItemPolished(controlUnderTest)
            tryVerify(function () {
                return controlUnderTest.controller.regularTokensModel.count > 1
                    && !!findChild(controlUnderTest, "manageTokensDelegate-0")
                    && !!findChild(controlUnderTest, "manageTokensDelegate-1")
            })

            const delegate1 = findChild(controlUnderTest, "manageTokensDelegate-1")
            const titleToTest = delegate1.title
            const delegate0 = findChild(controlUnderTest, "manageTokensDelegate-0")
            verify(delegate0.title !== titleToTest)

            triggerDelegateMenuAction(1, "miMoveToTop")
            waitForItemPolished(controlUnderTest)
            tryCompare(findChild(controlUnderTest, "manageTokensDelegate-0"), "title", titleToTest)

            verify(controlUnderTest.dirty)
            controlUnderTest.saveSettings(false /* update */)
            verify(!controlUnderTest.dirty)

            controlUnderTest.revert()
            verify(!controlUnderTest.dirty)
            waitForItemPolished(controlUnderTest)
            tryVerify(function () {
                const item = findChild(controlUnderTest, "manageTokensDelegate-0")
                return !!item && item.title === titleToTest
            })
        }

        function test_reorderAssetsByDragging() {
            verify(!controlUnderTest.dirty)
            verify(controlUnderTest.controller.regularTokensModel.count > 1)

            const delegate0 = findChild(controlUnderTest, "manageTokensDelegate-0")
            verify(!!delegate0)
            const title0 = delegate0.title
            verify(!!title0)
            const delegate1 = findChild(controlUnderTest, "manageTokensDelegate-1")
            const title1 = delegate1.title
            verify(!!title1)

            waitForRendering(delegate1)

            mouseDrag(delegate1, delegate1.width / 2, delegate1.height / 2, 0, -delegate1.height)

            tryCompare(findChild(controlUnderTest, "manageTokensDelegate-0"), "title", title1)
            tryCompare(findChild(controlUnderTest, "manageTokensDelegate-1"), "title", title0)
            verify(controlUnderTest.dirty)
        }
    }
}

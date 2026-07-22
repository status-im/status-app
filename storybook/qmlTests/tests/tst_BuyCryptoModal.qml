import QtQuick
import QtTest

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Core.Backpressure

import utils

import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.stores

import shared.stores

import Models
import Mocks

Item {
    id: root
    width: 600
    height: 800

    QtObject {
        id: d

    }

    Component {
        id: componentUnderTest
        BuyCryptoModal {
            id: buySellModal

            buyProvidersModel: buyCryptoStore.providersModel
            isBuyProvidersModelLoading: buyCryptoStore.areProvidersLoading
            formatCurrencyBalance: (amount) => currencyStore.formatCurrencyAmount(amount, currencyStore.currentCurrency)
            walletAccountsModel: WalletAccountsModel{}
            networksModel: NetworksModel.flatNetworks
            tokenGroupsModel: assetsStore.walletTokensStore.tokenGroupsModel
            groupedAccountAssetsModel: assetsStore.groupedAccountAssetsModel
            // Stub for the terminal picker model. Mirrors the eth-native group's
            // multi-chain tokens so BuyCryptoModalAdaptor's provider/chain filter
            // behaves as it did against the retired adaptor's output.
            tokenSelectorModel: TokenSelectorModelMock {
                sourceData: [
                    {
                        key: Constants.ethGroupKey, name: "Ether", symbol: Constants.ethToken,
                        logoUri: Constants.tokenIcon(Constants.ethToken), decimals: 18,
                        currencyBalance: 0, cryptoPrice: 0, sectionName: "Popular assets",
                        balances: [],
                        tokens: [
                            { key: "1-0x0000000000000000000000000000000000000000", chainId: 1 },
                            { key: "10-0x0000000000000000000000000000000000000000", chainId: 10 },
                            { key: "42161-0x0000000000000000000000000000000000000000", chainId: 42161 },
                            { key: "11155111-0x0000000000000000000000000000000000000000", chainId: 11155111 },
                            { key: "11155420-0x0000000000000000000000000000000000000000", chainId: 11155420 },
                            { key: "421614-0x0000000000000000000000000000000000000000", chainId: 421614 }
                        ]
                    }
                ]
            }
            buyCryptoInputParamsForm: BuyCryptoParamsForm {
                selectedWalletAddress: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
                selectedNetworkChainId: 11155111
                selectedTokenGroupKey: Constants.ethGroupKey
            }
            Component.onCompleted: {
                fetchProviders.connect(buyCryptoStore.fetchProviders)
                fetchProviderUrl.connect(buyCryptoStore.fetchProviderUrl)
                buyCryptoStore.providerUrlReady.connect(buySellModal.providerUrlReady)
            }

            // Temporary assignments to make tests run independently
            readonly property var currencyStore: CurrenciesStore {}
            readonly property var buyCryptoStore: BuyCryptoStore {
                readonly property var providersModel: OnRampProvidersModel{}
                property bool areProvidersLoading
                signal providerUrlReady(string uuid ,string url)

                function fetchProviders() {
                    console.warn("fetchProviders called >>")
                    areProvidersLoading = true
                    debounceFetchProvidersList()
                }

                function fetchProviderUrl(uuid, providerID,
                                          isRecurrent, accountAddress = "",
                                          chainID = 0, symbol = "") {
                    console.warn("fetchProviderUrl called >> uuid: ", uuid, "providerID: ",providerID
                                 , "isRecurrent: ", isRecurrent, "accountAddress: ", accountAddress,
                                 "chainID: ", chainID, "symbol: ", symbol)
                    buySellModal.uuid = uuid
                    debounceFetchProviderUrl()
                }
            }
            readonly property ModelEntry selectedAccountEntry: ModelEntry {
                sourceModel: walletAccountsModel
                key: "address"
                value: buyCryptoInputParamsForm.selectedWalletAddress
            }
            readonly property ModelEntry selectedProviderEntry: ModelEntry {
                sourceModel: buyCryptoStore.providersModel
                key: "id"
                value: buyCryptoInputParamsForm.selectedProviderId
            }
            readonly property var recurrentOnRampProvidersModel: SortFilterProxyModel {
                sourceModel: buyProvidersModel
                filters: ValueFilter {
                    roleName: "supportsRecurrentPurchase"
                    value: true
                }
            }
            readonly property var assetsStore: WalletAssetsStoreMock {
                id: thisWalletAssetStore
                walletTokensStore: TokensStoreMock {
                    tokenGroupsModel: TokenGroupsModel {}
                }
            }
            property string uuid
            property var debounceFetchProviderUrl: Backpressure.debounce(root, 500, function() {
                buySellModal.buyCryptoStore.providerUrlReady(uuid, "xxxx")
            })
            property var debounceFetchProvidersList: Backpressure.debounce(root, 500, function() {
                if (buySellModal && buySellModal.buyCryptoStore) {
                    buySellModal.buyCryptoStore.areProvidersLoading = false
                }
            })
        }
    }

    SignalSpy {
        id: notificationSpy
        target: Global
        signalName: "requestOpenLink"
    }

    TestCase {
        name: "BuyCryptoModal"
        when: windowShown

        property BuyCryptoModal controlUnderTest: null

        function init() {
            notificationSpy.clear()
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function launchPopup() {
            verify(!!controlUnderTest)
            controlUnderTest.buyCryptoInputParamsForm.selectedWalletAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            controlUnderTest.buyCryptoInputParamsForm.selectedNetworkChainId = 11155111
            controlUnderTest.buyCryptoInputParamsForm.selectedTokenGroupKey = Constants.ethGroupKey
            controlUnderTest.open()
            tryVerify(() => !!controlUnderTest.opened)
        }

        function testDelegateItems(providersList, modelToCompareAgainst) {
            for(let i =0; i< providersList.count; i++) {
                let delegateUnderTest = providersList.itemAtIndex(i)
                verify(!!delegateUnderTest)

                tryCompare(delegateUnderTest, "title", modelToCompareAgainst.get(i).name)
                compare(delegateUnderTest.asset.name, modelToCompareAgainst.get(i).logoUrl)
                compare(delegateUnderTest.isUrlLoading, false)

                const feesText = findChild(delegateUnderTest, "feesText")
                verify(!!feesText)
                compare(feesText.text, modelToCompareAgainst.get(i).fees)

                const loadingIndicator = findChild(delegateUnderTest, "loadingIndicator")
                verify(!!loadingIndicator)
                verify(!loadingIndicator.visible)

                var extraIcon = null
                if (modelToCompareAgainst.get(i).urlsNeedParameters) {
                    extraIcon = findChild(delegateUnderTest, "chevron-down-icon")
                    verify(!!extraIcon)
                    compare(extraIcon.icon, "chevron-down")
                    compare(extraIcon.rotation, 270)
                    compare(extraIcon.color, Theme.palette.baseColor1)
                } else {
                    extraIcon = findChild(delegateUnderTest, "tiny/external-icon")
                    verify(!!extraIcon)
                    compare(extraIcon.icon, "tiny/external")
                    compare(extraIcon.rotation, 0)
                    compare(extraIcon.color, Theme.palette.baseColor1)
                }

                // Hover over the item and check hovered state
                mouseMove(delegateUnderTest, delegateUnderTest.width/2, delegateUnderTest.height/2)
                verify(delegateUnderTest.sensor.containsMouse)
                compare(extraIcon.color, Theme.palette.directColor1)
                verify(delegateUnderTest.color, Theme.palette.baseColor2)
            }
        }

        function testDelegateMouseClicksForProvidersThatNeedParams(delegateUnderTest, modelData) {
            const loadingIndicator = findChild(delegateUnderTest, "loadingIndicator")
            verify(!!loadingIndicator)
            verify(!loadingIndicator.visible)

            verify(!controlUnderTest.replaceItem)

            // test mouse click
            tryCompare(notificationSpy, "count", 0)
            mouseClick(delegateUnderTest)

            waitForRendering(controlUnderTest.replaceLoader)
            verify(controlUnderTest.replaceItem)

            const selectParamsPanel = findChild(controlUnderTest, "selectParamsPanel")
            verify(!!selectParamsPanel)

            // title should not change
            verify(controlUnderTest.stackTitle, qsTr("Ways to buy assets %1").arg(!!controlUnderTest.selectedAccountEntry.item ? controlUnderTest.selectedAccountEntry.item.name: ""))

            compare(controlUnderTest.rightButtons.length, 2)
            verify(controlUnderTest.rightButtons[0].visible)
            verify(controlUnderTest.rightButtons[1].enabled)
            verify(controlUnderTest.rightButtons[0].text, qsTr("Buy via %1").arg(!!controlUnderTest.selectedProviderEntry.item ? controlUnderTest.selectedProviderEntry.item.name: ""))
            verify(!controlUnderTest.rightButtons[1].visible)
            verify(controlUnderTest.backButton.visible)

            const selectParamsForBuyCryptoPanelHeader = findChild(selectParamsPanel, "selectParamsForBuyCryptoPanelHeader")
            verify(!!selectParamsForBuyCryptoPanelHeader)
            compare(selectParamsForBuyCryptoPanelHeader.title, qsTr("Buy via %1").arg(!!controlUnderTest.selectedProviderEntry.item ? controlUnderTest.selectedProviderEntry.item.name: ""))
            compare(selectParamsForBuyCryptoPanelHeader.subTitle, qsTr("Select which network and asset"))
            compare(selectParamsForBuyCryptoPanelHeader.statusListItemTitle.color, Theme.palette.directColor1)
            compare(selectParamsForBuyCryptoPanelHeader.asset.name, !!controlUnderTest.selectedProviderEntry.item  ? controlUnderTest.selectedProviderEntry.item .logoUrl: "")
            compare(selectParamsForBuyCryptoPanelHeader.color, StatusColors.transparent)
            compare(selectParamsForBuyCryptoPanelHeader.enabled, false)

            const networkFilter = findChild(selectParamsPanel, "networkFilter")
            verify(!!networkFilter)
            compare(networkFilter.selection, [controlUnderTest.buyCryptoInputParamsForm.selectedNetworkChainId])

            const tokenSelector = findChild(selectParamsPanel, "assetSelector")
            verify(!!tokenSelector)

            compare(selectParamsPanel.selectedTokenGroupKey, controlUnderTest.buyCryptoInputParamsForm.selectedTokenGroupKey)

            const selectedAssetButton = findChild(tokenSelector, "assetSelectorButton")
            verify(!!selectedAssetButton)

            const modelDataToTest = ModelUtils.getByKey(tokenSelector.model, "key",
                                                        controlUnderTest.buyCryptoInputParamsForm.selectedTokenGroupKey)
            compare(selectedAssetButton.selected, true)
            compare(selectedAssetButton.icon, modelDataToTest.logoUri)
            compare(selectedAssetButton.name, modelDataToTest.name)
            compare(selectedAssetButton.subname, modelDataToTest.symbol)

            //switch to a network that has no tokens and ensure its reset
            controlUnderTest.buyCryptoInputParamsForm.selectedNetworkChainId = 421614

            waitForRendering(selectParamsPanel)

            compare(selectedAssetButton.selected, false)
            verify(!controlUnderTest.rightButtons[0].enabled)

            // switch back a network and token thats valid and check if clicking buy button works properly
            controlUnderTest.buyCryptoInputParamsForm.selectedNetworkChainId = 11155111
            controlUnderTest.buyCryptoInputParamsForm.selectedTokenGroupKey = Constants.ethGroupKey

            waitForRendering(selectParamsPanel)
            verify(controlUnderTest.rightButtons[0].enabled)

            mouseClick(controlUnderTest.rightButtons[0])

            verify(controlUnderTest.rightButtons[0].loading)
            tryCompare(notificationSpy, "count", 1)
            compare(notificationSpy.signalArguments[0][0], "xxxx")
            notificationSpy.clear()

            // popup should be closed
            verify(!controlUnderTest.opened)
        }

        function testDelegateMouseClicksForProvidersThatNeedNoParams(delegateUnderTest, modelData) {
            // test provider that need no parameters and we directly redirect to the site
            const loadingIndicator = findChild(delegateUnderTest, "loadingIndicator")
            verify(!!loadingIndicator)
            verify(!loadingIndicator.visible)

            const extraIcon = findChild(delegateUnderTest, "tiny/external-icon")
            verify(!!extraIcon)
            verify(!extraIcon.visble)

            // test mouse click
            tryCompare(notificationSpy, "count", 0)
            mouseClick(delegateUnderTest)

            verify(loadingIndicator.visible)
            tryCompare(notificationSpy, "count", 1)
            compare(notificationSpy.signalArguments[0][0], "xxxx")
            notificationSpy.clear()

            // popup should be closed
            verify(!controlUnderTest.opened)
        }

        function test_launchAndCloseModal() {
            launchPopup()

            // close popup
            controlUnderTest.close()
            verify(!controlUnderTest.opened)
        }

        function test_ModalFooter() {
            // Launch modal
            launchPopup()

            // check if footer has Done button and action on button clicked
            compare(controlUnderTest.rightButtons.length, 2)
            verify(!controlUnderTest.rightButtons[0].visible)
            verify(controlUnderTest.rightButtons[1].visible)
            compare(controlUnderTest.rightButtons[1].text, qsTr("Done"))
            mouseClick(controlUnderTest.rightButtons[1])

            verify(!controlUnderTest.backButton.visible)

            // popup should be closed
            verify(!controlUnderTest.opened)
        }

        function test_modalContent() {
            // Launch modal
            launchPopup()

            verify(controlUnderTest.stackTitle, qsTr("Ways to buy assets for %1").arg(!!controlUnderTest.selectedAccountEntry.item ? controlUnderTest.selectedAccountEntry.item.name: ""))

            // // find tab bar
            // const tabBar = findChild(controlUnderTest, "tabBar")
            // verify(!!tabBar)

            // find providers list
            const providersList = findChild(controlUnderTest, "providersList")
            waitForRendering(providersList)
            verify(!!providersList)

            // // should have 2 items
            // compare(tabBar.count, 2)

            // // current index set should be to 0
            // compare(tabBar.currentIndex, 0)

            // // item 0 should have text "One time"
            // compare(tabBar.itemAt(0).text, qsTr("One time"))

            // // item 1 should have text "Recurrent"
            // compare(tabBar.itemAt(1).text, qsTr("Recurrent"))

            // close popup
            controlUnderTest.close()
            verify(!controlUnderTest.opened)
        }

        function test_modalContent_OneTime_tab() {
            notificationSpy.clear()
            // Launch modal
            launchPopup()

            // // find tab bar
            // const tabBar = findChild(controlUnderTest, "tabBar")
            // verify(!!tabBar)

            // find providers list
            const providersList = findChild(controlUnderTest, "providersList")
            verify(!!providersList)

            tryCompare(controlUnderTest, "isBuyProvidersModelLoading", false)

            // mouseClick(tabBar.itemAt(0))
            // compare(tabBar.currentIndex, 0)

            // verify that 4 items are listed
            compare(providersList.count, 4)

            // check if delegate contents are as expected
            testDelegateItems(providersList, controlUnderTest.buyProvidersModel)

            controlUnderTest.close()
        }

        function test_modalContent_OneTime_tab_mouseClicks() {
            notificationSpy.clear()
            // Launch modal
            launchPopup()

            // find providers list
            const providersList = findChild(controlUnderTest, "providersList")
            verify(!!providersList)

            for(let i =0; i< controlUnderTest.buyProvidersModel.count; i++) {
                notificationSpy.clear()
                launchPopup()
                verify(controlUnderTest.opened)

                tryCompare(controlUnderTest, "isBuyProvidersModelLoading", false)

                let delegateUnderTest = providersList.itemAtIndex(i)
                verify(!!delegateUnderTest)
                waitForRendering(delegateUnderTest)

                // test provider that need parameters like network and token to be selected
                const modelData = controlUnderTest.buyProvidersModel.get(i)
                verify(!!modelData)
                if (modelData.urlsNeedParameters) {
                    testDelegateMouseClicksForProvidersThatNeedParams(delegateUnderTest, modelData)
                } else {
                    testDelegateMouseClicksForProvidersThatNeedNoParams(delegateUnderTest, modelData)
                }
            }

            controlUnderTest.close()
        }

        // function test_modalContent_recurrent_tab() {
        //     skip("to be fixed in 16462")
        //     notificationSpy.clear()
        //     // Launch modal
        //     launchPopup()

        //     // find tab bar
        //     const tabBar = findChild(controlUnderTest, "tabBar")
        //     verify(!!tabBar)

        //     // find providers list
        //     const providersList = findChild(controlUnderTest, "providersList")
        //     verify(!!providersList)

        //     tryCompare(controlUnderTest, "isBuyProvidersModelLoading", false)

        //     // check data in "Recurrent" tab --------------------------------------------------------
        //     mouseClick(tabBar.itemAt(1))
        //     compare(tabBar.currentIndex, 1)
        //     waitForRendering(providersList)
        //     verify(!!providersList)

        //     // verify that 1 item is listed
        //     compare(providersList.count, 1)

        //     // check if delegate contents are as expected
        //     testDelegateItems(providersList, controlUnderTest.recurrentOnRampProvidersModel)
        //     controlUnderTest.close()
        // }

        // function test_modalContent_Recurrent_tab_mouseClicks() {
        //     notificationSpy.clear()
        //     // Launch modal
        //     launchPopup()

        //     // find tab bar
        //     const tabBar = findChild(controlUnderTest, "tabBar")
        //     verify(!!tabBar)

        //     // find providers list
        //     const providersList = findChild(controlUnderTest, "providersList")
        //     verify(!!providersList)

        //     mouseClick(tabBar.itemAt(1))
        //     compare(tabBar.currentIndex, 1)
        //     waitForRendering(providersList)
        //     verify(!!providersList)

        //     for(let i =0; i< controlUnderTest.recurrentOnRampProvidersModel.count; i++) {
        //         notificationSpy.clear()
        //         launchPopup()
        //         verify(controlUnderTest.opened)

        //         tryCompare(controlUnderTest, "isBuyProvidersModelLoading", false)

        //         let delegateUnderTest = providersList.itemAtIndex(i)
        //         verify(!!delegateUnderTest)
        //         waitForRendering(delegateUnderTest)

        //         // test provider that need parameters like network and token to be selected
        //         const modelData = controlUnderTest.recurrentOnRampProvidersModel.get(i)
        //         verify(!!modelData)
        //         if (modelData.urlsNeedParameters) {
        //             testDelegateMouseClicksForProvidersThatNeedParams(delegateUnderTest, modelData)
        //         } else {
        //             testDelegateMouseClicksForProvidersThatNeedNoParams(delegateUnderTest, modelData)
        //         }
        //     }
        // }
    }
}

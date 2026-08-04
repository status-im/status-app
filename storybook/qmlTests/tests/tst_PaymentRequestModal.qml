import QtQuick
import QtTest

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls

import QtQuick.Controls

import utils

import AppLayouts.Wallet.adaptors
import AppLayouts.Chat.popups
import shared.stores as SharedStores

import Storybook
import Models
import Mocks

Item {
    id: root
    width: 800
    height: 600

    QtObject {
        id: d

        readonly property var accounts: WalletAccountsModel {}
        readonly property var flatNetworks: NetworksModel.flatNetworks

        readonly property var tokensStore: TokensStoreMock {
            tokenGroupsModel: TokenGroupsModel {}
            tokenGroupsForChainModel: TokenGroupsModel {
                skipInitialLoad: true
            }
            searchResultModel: TokenGroupsModel {
                skipInitialLoad: true
                tokenGroupsForChainModel: d.tokensStore.tokenGroupsForChainModel
            }
        }
    }

    Component {
        id: paymentRequestModalComponent
        PaymentRequestModal {
            id: paymentRequestModal
            destroyOnClose: true

            readonly property SharedStores.CurrenciesStore currencyStore: SharedStores.CurrenciesStore {}

            currentCurrency: currencyStore.currentCurrency
            formatCurrencyAmount: currencyStore.formatCurrencyAmount
            flatNetworksModel: d.flatNetworks
            accountsModel: d.accounts
            tokenGroupsForChainModel: d.tokensStore.tokenGroupsForChainModel
            searchResultModel: d.tokensStore.searchResultModel

            Component.onCompleted: {
                d.tokensStore.buildGroupsForChain(paymentRequestModal.selectedNetworkChainId)
            }

            onBuildGroupsForChain: {
                d.tokensStore.buildGroupsForChain(paymentRequestModal.selectedNetworkChainId)
            }

            onSelectedNetworkChainIdChanged: {
                d.tokensStore.buildGroupsForChain(paymentRequestModal.selectedNetworkChainId)
            }
        }
    }

    TestCase {
        name: "PaymentRequestModal"
        when: windowShown

        property PaymentRequestModal controlUnderTest: null

        // helper functions -------------------------------------------------------------
        function launchAndVerfyModal() {
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root)
            verify(!!controlUnderTest)
            controlUnderTest.open()
            waitForRendering(controlUnderTest.contentItem)
            tryVerify(() => !!controlUnderTest.opened)
        }

        function closeAndVerfyModal() {
            verify(!!controlUnderTest)
            controlUnderTest.close()
            verify(!controlUnderTest.opened)
        }
        // end helper functions -------------------------------------------------------------

        function test_default_values() {
            launchAndVerfyModal()

            const button = findChild(controlUnderTest, "addButton")
            verify(!!button)
            verify(!button.enabled)

            compare(controlUnderTest.selectedTokenGroupKey, Constants.ethGroupKey)
            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)
            verify(assetSelector.isSelected)
            verify(assetSelector.contentItem.selected)
            compare(assetSelector.contentItem.name, Constants.ethToken)

            compare(controlUnderTest.selectedNetworkChainId, Constants.chains.mainnetChainId)
            const networkSelector = findChild(controlUnderTest, "networkSelector")
            verify(!!networkSelector)
            compare(networkSelector.control.contentItem.title, Constants.networkMainnet)
            compare(networkSelector.count, d.flatNetworks.count)

            compare(controlUnderTest.selectedAccountAddress, d.accounts.data[0].address)
            const accountSelector = findChild(controlUnderTest, "accountSelector")
            verify(!!accountSelector)
            compare(accountSelector.control.contentItem.name, d.accounts.data[0].name)
            compare(accountSelector.count, d.accounts.data.length)

            compare(controlUnderTest.amount, "0")
            const amountInput = findChild(controlUnderTest, "amountInput")
            verify(!!amountInput)
            compare(amountInput.text, "")

            closeAndVerfyModal()
        }

        function test_change_amount() {
            launchAndVerfyModal()

            // Wait for the model to be populated and selection to be ready
            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)
            tryCompare(assetSelector.contentItem, "name", Constants.ethToken, 5000)

            const amountInput = findChild(controlUnderTest, "amountInput")
            verify(!!amountInput)

            tryVerify(() => amountInput.multiplierIndex > 0, 5000)

            const amount = "1.24"
            amountInput.setValue(amount)

            compare(amountInput.text, amount)
            compare(controlUnderTest.amount, "1240000000000000000")

            closeAndVerfyModal()
        }

        function test_change_address() {
            launchAndVerfyModal()

            const accountSelector = findChild(controlUnderTest, "accountSelector")
            verify(!!accountSelector)

            const account = d.accounts.data[1]
            mouseClick(accountSelector)
            verify(accountSelector.control.popup.opened)
            waitForRendering(accountSelector.control.popup.contentItem)
            const delegateUnderTest = accountSelector.control.popup.contentItem.itemAtIndex(1)
            verify(!!delegateUnderTest)
            mouseClick(delegateUnderTest)
            verify(!accountSelector.control.popup.opened)

            compare(controlUnderTest.selectedAccountAddress, account.address)
            compare(accountSelector.control.contentItem.name, account.name)

            closeAndVerfyModal()
        }

        function test_change_symbol() {
            launchAndVerfyModal()

            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)
            compare(controlUnderTest.selectedTokenGroupKey, Constants.ethGroupKey)
            compare(assetSelector.contentItem.name, "ETH")

            const asset = SQUtils.ModelUtils.get(assetSelector.model, 2)
            verify(!!asset)
            compare(asset.key, Constants.daiGroupKey)
            mouseClick(assetSelector)

            waitForRendering(assetSelector)
            const searchablePanel = findChild(assetSelector, "searchableAssetsPanel")
            verify(!!searchablePanel)
            const assetsList = findChild(searchablePanel, "assetsListView")
            verify(!!assetsList)
            const delegateUnderTest = assetsList.itemAtIndex(2)
            verify(!!delegateUnderTest)
            compare(delegateUnderTest.rowAt(0).symbol, "DAI")
            mouseClick(delegateUnderTest.rowAt(0))

            compare(controlUnderTest.selectedTokenGroupKey, Constants.daiGroupKey)
            compare(assetSelector.contentItem.name, "DAI")

            closeAndVerfyModal()
        }

        function test_change_network() {
            launchAndVerfyModal()

            const networkSelector = findChild(controlUnderTest, "networkSelector")
            verify(!!networkSelector)

            const network = d.flatNetworks.get(1)
            mouseClick(networkSelector)
            verify(networkSelector.control.popup.opened)
            waitForRendering(networkSelector.control.popup.contentItem)
            const delegateUnderTest = networkSelector.control.popup.contentItem.itemAtIndex(1)
            verify(!!delegateUnderTest)
            mouseClick(delegateUnderTest)
            verify(!networkSelector.control.popup.opened)

            compare(controlUnderTest.selectedNetworkChainId, network.chainId)
            compare(networkSelector.control.contentItem.title, network.chainName)

            closeAndVerfyModal()
        }

        function test_symbol_initial_selection_when_not_available_in_chain() {
            const assetGroupKey = Constants.sttGroupKey
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root, { selectedTokenGroupKey: assetGroupKey, selectedNetworkChainId: Constants.chains.mainnetChainId })
            verify(!!controlUnderTest)

            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)
            tryCompare(assetSelector.contentItem, "name", "ETH")
            compare(controlUnderTest.selectedTokenGroupKey, Constants.ethGroupKey)
        }

        function test_symbol_selection_after_network_change() {
            const assetGroupKey = Constants.sttGroupKey
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root, { selectedNetworkChainId: Constants.chains.arbitrumSepoliaChainId })
            verify(!!controlUnderTest)

            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            // TODO: Fix the model population issue. We should be able to set the initial asset when building the control.
            controlUnderTest.selectedTokenGroupKey = assetGroupKey
            wait(1000) // wait until change is conducted (because of callLater call in selectedHolding)

            compare(controlUnderTest.selectedNetworkChainId, Constants.chains.arbitrumSepoliaChainId)
            compare(controlUnderTest.selectedTokenGroupKey, assetGroupKey)
            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)

            compare(assetSelector.contentItem.name, "STT")

            controlUnderTest.selectedNetworkChainId = Constants.chains.mainnetChainId
            tryCompare(assetSelector.contentItem, "name", "ETH")
            compare(controlUnderTest.selectedTokenGroupKey, Constants.ethGroupKey)
        }

        function test_open_initial_account_address() {
            const account = d.accounts.data[1]
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root, { selectedAccountAddress: account.address })
            verify(!!controlUnderTest)

            controlUnderTest.open()
            tryVerify(() => !!controlUnderTest.opened)

            compare(controlUnderTest.selectedAccountAddress, account.address)
            const accountSelector = findChild(controlUnderTest, "accountSelector")
            verify(!!accountSelector)
            compare(accountSelector.control.contentItem.name, account.name)

            closeAndVerfyModal()
        }

        function test_open_initial_network() {
            const network = d.flatNetworks.get(2)
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root, { selectedNetworkChainId: network.chainId })
            verify(!!controlUnderTest)

            controlUnderTest.open()
            tryVerify(() => !!controlUnderTest.opened)

            compare(controlUnderTest.selectedNetworkChainId, network.chainId)
            const networkSelector = findChild(controlUnderTest, "networkSelector")
            verify(!!networkSelector)
            compare(networkSelector.control.contentItem.title, network.chainName)

            closeAndVerfyModal()
        }

        function test_open_initial_asset() {
            const assetGroupKey = Constants.daiGroupKey
            const assetSymbol = "DAI"
            controlUnderTest = createTemporaryObject(paymentRequestModalComponent, root)
            verify(!!controlUnderTest)

            controlUnderTest.open()
            tryVerify(() => !!controlUnderTest.opened)
            // TODO: Fix the model population issue. We should be able to set the initial asset when building the control.
            controlUnderTest.selectedTokenGroupKey = assetGroupKey

            compare(controlUnderTest.selectedTokenGroupKey, assetGroupKey)
            wait(1000) // wait until change is conducted (because of callLater call in selectedHolding)
            const assetSelector = findChild(controlUnderTest, "assetSelector")
            verify(!!assetSelector)
            verify(assetSelector.isSelected)
            verify(assetSelector.contentItem.selected)
            compare(assetSelector.contentItem.name, assetSymbol)

            closeAndVerfyModal()
        }

        function test_accept_button_enabled_state() {
            launchAndVerfyModal()

            const button = findChild(controlUnderTest, "addButton")
            verify(!!button)

            verify(!button.enabled, "Enabled by default because default amount is 0")

            const amountInput = findChild(controlUnderTest, "amountInput")
            verify(!!amountInput)
            amountInput.setValue("1.24")
            verify(button.enabled, "All values are filled")
            amountInput.setValue("0")
            verify(!button.enabled, "Amount cannot be 0")

            amountInput.setValue("2")
            verify(button.enabled)

            // Below scenarios are unlikely to happen in real life, but we should test them anyway.
            // This might produce warnings in the console, but it's fine.

            // Check if button changes after network is changed
            controlUnderTest.selectedNetworkChainId = 0
            verify(!button.enabled)
            controlUnderTest.selectedNetworkChainId = d.flatNetworks.get(1).chainId
            verify(button.enabled)

            // Check if button changes after account is changed
            controlUnderTest.selectedAccountAddress = ""
            verify(!button.enabled)
            controlUnderTest.selectedAccountAddress = d.accounts.data[1].address
            verify(button.enabled)

            // Check if button changes after symbol is changed
            controlUnderTest.selectedTokenGroupKey = ""
            verify(!button.enabled)
            controlUnderTest.selectedTokenGroupKey = Constants.daiGroupKey
            verify(button.enabled)

            closeAndVerfyModal()
        }
    }
}

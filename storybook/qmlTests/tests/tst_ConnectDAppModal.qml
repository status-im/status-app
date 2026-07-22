import QtQuick
import QtTest

import shared.popups.walletconnect

import Models

Item {
    id: root
    width: 1200
    height: 800

    Component {
        id: accountsModelComponent
        WalletAccountsModel {}
    }

    Component {
        id: componentUnderTest
        ConnectDAppModal {
            id: controlUnderTest
            modal: false
            anchors.centerIn: parent
            accounts: WalletAccountsModel {}
            flatNetworks: NetworksModel.flatNetworks
        }
    }

    TestCase {
        id: testConnectDappModal
        name: "ConnectDappModalTest"
        when: windowShown

        SignalSpy {
            id: connectSignalSpy
            target: testConnectDappModal.dappModal
            signalName: "connect"
        }

        SignalSpy {
            id: declineSignalSpy
            target: testConnectDappModal.dappModal
            signalName: "decline"
        }

        SignalSpy {
            id: disconnectSignalSpy
            target: testConnectDappModal.dappModal
            signalName: "disconnect"
        }

        property ConnectDAppModal dappModal: null

        function cleanup() {
            connectSignalSpy.clear()
            declineSignalSpy.clear()
            disconnectSignalSpy.clear()
        }

        function test_initialState() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true})

            tryVerify(() => dappModal.opened)

            verify(dappModal.visible, "ConnectDAppModal should be visible")
            verify(dappModal.accounts, "ConnectDAppModal should have accounts")
            verify(dappModal.flatNetworks, "ConnectDAppModal should have networks")

            compare(dappModal.width, 480)
            compare(dappModal.dAppName, "")
            compare(dappModal.dAppUrl, "")
            compare(dappModal.dAppIconUrl, "")
            compare(dappModal.connectionStatus, dappModal.notConnectedStatus)
        }

        function test_notConnectedState() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true})
            tryVerify(() => dappModal.opened)

            compare(dappModal.connectionStatus, dappModal.notConnectedStatus)

            // Reject button should be enabled
            const rejectButton = findChild(dappModal, "rejectButton")
            verify(rejectButton, "Reject button should be present")
            compare(rejectButton.text, "Reject")
            compare(rejectButton.enabled, true)
            mouseClick(rejectButton)
            compare(declineSignalSpy.count, 1)
            
            // Connect button should be enabled
            const connectButton = findChild(dappModal, "primaryActionButton")
            verify(connectButton, "Connect button should be present")
            compare(connectButton.text, "Connect")
            compare(connectButton.enabled, true)
            mouseClick(connectButton)
            compare(connectSignalSpy.count, 1)

            // Disconnect button should be disabled
            const disconnectButton = findChild(dappModal, "disconnectButton")
            verify(disconnectButton, "Disconnect button should be present")
            compare(disconnectButton.text, "Disconnect")
            compare(disconnectButton.visible, false)
            mouseClick(disconnectButton)
            compare(disconnectSignalSpy.count, 0)

            // Account selector should be enabled and user should be able to select an account
            const accountSelector = findChild(dappModal, "accountSelector")
            verify(accountSelector, "Account selector should be present")
            compare(accountSelector.enabled, true)
            compare(accountSelector.currentIndex, 0)
            mouseClick(accountSelector)
            compare(accountSelector.popup.visible, true)

            waitForItemPolished(accountSelector.popup.contentItem)

            const accountsList = findChild(accountSelector, "accountSelectorList")
            verify(accountsList, "Accounts list should be present")
            const selectAddress = accountsList.itemAtIndex(1).address
            mouseClick(accountsList.itemAtIndex(1))
            compare(dappModal.selectedAccountAddress, accountSelector.currentAccountAddress)
            compare(dappModal.selectedAccountAddress, selectAddress)

            // Chain selector is enabled, all common chains preselected
            const chainSelector = findChild(dappModal, "networkFilter")
            verify(chainSelector, "Chain selector should be present")
            compare(chainSelector.enabled, true)
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)
            compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count)

            // TODO uncomment after we enable chain selection (maybe v2.31)
            // // User should be able to deselect a chain
            // mouseClick(chainSelector)
            // waitForItemPolished(chainSelector)
            // const networkSelectorList = findChild(chainSelector, "networkSelectorList")
            // verify(networkSelectorList, "Network selector list should be present")
            // mouseClick(networkSelectorList.itemAtIndex(0))
            // compare(chainSelector.selection.length, NetworksModel.flatNetworks.count - 1)
            // compare(chainSelector.selection[0], NetworksModel.flatNetworks.get(1).chainId)
            // compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count - 1)
            // compare(dappModal.selectedChains[0], NetworksModel.flatNetworks.get(1).chainId)
        }

        function test_connectedState() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true})
            tryVerify(() => dappModal.opened)
            dappModal.pairSuccessful()
            compare(dappModal.connectionStatus, dappModal.connectionSuccessfulStatus)

            // Reject button should not be visible
            const rejectButton = findChild(dappModal, "rejectButton")
            verify(rejectButton, "Reject button should be present")
            compare(rejectButton.visible, false)
            mouseClick(rejectButton)
            compare(declineSignalSpy.count, 0)

            // Close button should be enabled
            const closeButton = findChild(dappModal, "primaryActionButton")
            verify(closeButton, "Close button should be present")
            compare(closeButton.text, "Close")
            compare(closeButton.enabled, true)
            compare(closeButton.visible, true)
            mouseClick(closeButton)
            compare(dappModal.opened, false)
            dappModal.open()
            tryVerify(() => dappModal.opened)

            // Disconnect button should be enabled
            const disconnectButton = findChild(dappModal, "disconnectButton")
            verify(disconnectButton, "Disconnect button should be present")
            compare(disconnectButton.text, "Disconnect")
            compare(disconnectButton.visible, true)
            compare(disconnectButton.enabled, true)
            mouseClick(disconnectButton)
            compare(disconnectSignalSpy.count, 1)

            // Account selector should be disabled
            const accountSelector = findChild(dappModal, "accountSelector")
            verify(accountSelector, "Account selector should be present")
            compare(accountSelector.currentIndex, 0)
            mouseClick(accountSelector)
            compare(accountSelector.popup.visible, false)

            // Chain selector is disabled
            const chainSelector = findChild(dappModal, "networkFilter")
            verify(chainSelector, "Chain selector should be present")
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)

            // User should not be able to open the popup; its content stays
            // unloaded since it is only created on first open
            mouseClick(chainSelector)
            waitForItemPolished(chainSelector)
            verify(!findChild(chainSelector, "networkSelectorList"))
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)
            compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count)
            verify(!chainSelector.control.popup.opened)

            const connectionTag = findChild(dappModal, "connectionStatusTag")
            compare(connectionTag.visible, true)
            compare(connectionTag.success, true)
        }

        function test_connectionFailedState() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true})
            tryVerify(() => dappModal.opened)
            dappModal.pairFailed()
            compare(dappModal.connectionStatus, dappModal.connectionFailedStatus)

            // Reject button should not be visible
            const rejectButton = findChild(dappModal, "rejectButton")
            verify(rejectButton, "Reject button should be present")
            compare(rejectButton.visible, false)
            mouseClick(rejectButton)
            compare(declineSignalSpy.count, 0)

            // Close button should be enabled
            const closeButton = findChild(dappModal, "primaryActionButton")
            verify(closeButton, "Close button should be present")
            compare(closeButton.text, "Close")
            compare(closeButton.enabled, true)
            compare(closeButton.visible, true)
            mouseClick(closeButton)
            compare(dappModal.opened, false)
            dappModal.open()

            // Disconnect button should not be visible
            const disconnectButton = findChild(dappModal, "disconnectButton")
            verify(disconnectButton, "Disconnect button should be present")
            compare(disconnectButton.text, "Disconnect")
            compare(disconnectButton.visible, false)
            mouseClick(disconnectButton)
            compare(disconnectSignalSpy.count, 0)

            // Account selector should be disabled
            const accountSelector = findChild(dappModal, "accountSelector")
            verify(accountSelector, "Account selector should be present")
            compare(accountSelector.currentIndex, 0)
            mouseClick(accountSelector)
            compare(accountSelector.popup.visible, false)

            // Chain selector is disabled
            const chainSelector = findChild(dappModal, "networkFilter")
            verify(chainSelector, "Chain selector should be present")
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)

            // User should not be able to open the popup; its content stays
            // unloaded since it is only created on first open
            mouseClick(chainSelector)
            waitForItemPolished(chainSelector)
            verify(!findChild(chainSelector, "networkSelectorList"))
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)
            compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count)
            verify(!chainSelector.control.popup.opened)

            const connectionTag = findChild(dappModal, "connectionStatusTag")
            compare(connectionTag.visible, true)
            compare(connectionTag.success, false)
        }

        function test_selectingAccount() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true, dAppChains: [1, 11155111]})
            tryVerify(() => dappModal.opened)

            const accountSelector = findChild(dappModal, "accountSelector")
            verify(accountSelector, "Account selector should be present")
            compare(accountSelector.currentIndex, 0)
            mouseClick(accountSelector)
            compare(accountSelector.popup.visible, true)

            waitForItemPolished(accountSelector.popup.contentItem)

            const accountsList = findChild(accountSelector, "accountSelectorList")
            verify(accountsList, "Accounts list should be present")
            compare(accountsList.count, dappModal.accounts.count)

            const selectAddress = accountsList.itemAtIndex(1).address
            mouseClick(accountsList.itemAtIndex(1))
            compare(dappModal.selectedAccountAddress, accountSelector.currentAccountAddress)
            compare(dappModal.selectedAccountAddress, selectAddress)

            const preselectedAddress = accountSelector.currentAccountAddress

            mouseClick(accountSelector)
            compare(accountSelector.popup.visible, true)

            waitForItemPolished(accountSelector.popup.contentItem)
            const selectAddress1 = accountsList.itemAtIndex(0).address
            mouseClick(accountsList.itemAtIndex(0))
            compare(dappModal.selectedAccountAddress, accountSelector.currentAccountAddress)
            compare(dappModal.selectedAccountAddress, selectAddress1)

            // Use preselected address
            dappModal.selectedAccountAddress = preselectedAddress
            compare(accountSelector.currentAccountAddress, preselectedAddress)
        }

        function test_chainSelection() {
            dappModal = createTemporaryObject(componentUnderTest, root, {visible: true})

            const chainSelector = findChild(dappModal, "networkFilter")
            verify(chainSelector, "Chain selector should be present")
            // All selected
            compare(chainSelector.selection.length, NetworksModel.flatNetworks.count)
            compare(chainSelector.selection[0], NetworksModel.flatNetworks.get(0).chainId)
            compare(chainSelector.selection[1],  NetworksModel.flatNetworks.get(1).chainId)

            // TODO uncomment after we enable chain selection (maybe v2.31)
            // // User should be able to deselect a chain
            // mouseClick(chainSelector)
            // waitForItemPolished(chainSelector)
            // const networkSelectorList = findChild(chainSelector, "networkSelectorList")
            // verify(networkSelectorList, "Network selector list should be present")
            // mouseClick(networkSelectorList.itemAtIndex(0))
            // compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count - 1)
            // compare(dappModal.selectedChains[0], NetworksModel.flatNetworks.get(1).chainId)

            // waitForItemPolished(networkSelectorList)
            // mouseClick(networkSelectorList.itemAtIndex(1))
            // compare(dappModal.selectedChains.length, NetworksModel.flatNetworks.count - 2)
            // compare(dappModal.selectedChains[0], NetworksModel.flatNetworks.get(2).chainId)

            // const connectButton = findChild(dappModal, "primaryActionButton")
            // verify(!!connectButton, "Connect button should be present")
            // compare(connectButton.visible, true)
            // compare(connectButton.enabled, true)
        }
    }
}

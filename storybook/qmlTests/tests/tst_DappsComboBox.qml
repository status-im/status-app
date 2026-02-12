import QtQuick
import QtQml.Models

import QtTest

import AppLayouts.Wallet.controls

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        DappsComboBox {
            id: controlUnderTest
            property SignalSpy dappListRequestedSpy: SignalSpy { target: controlUnderTest; signalName: "dappListRequested" }
            property SignalSpy connectDappSpy: SignalSpy { target: controlUnderTest; signalName: "connectDapp" }
            property SignalSpy disconnectDappSpy: SignalSpy { target: controlUnderTest; signalName: "disconnectDapp" }

            anchors.centerIn: parent
            model: ListModel {}
        }
    }

    property DappsComboBox controlUnderTest: null

    TestCase {
        name: "DappsComboBox"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_basicGeometry() {
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_showStatusIndicator() {
            const indicator = findChild(controlUnderTest, "dappBadge")
            compare(indicator.visible, false)

            controlUnderTest.model.append({name: "Test dApp 1", url: "https://dapp.test/1", iconUrl: "https://se-sdk-dapp.vercel.app/assets/eip155:1.png", connectorBadge: "status"})
            compare(indicator.visible, true)

            controlUnderTest.model.clear()
            compare(indicator.visible, false)
        }

        function test_dappIcon() {
            const icon = findChild(controlUnderTest, "dappIcon")
            compare(icon.icon, "dapp")
            compare(icon.width, 24)
            compare(icon.height, 24)
            compare(icon.status, Image.Ready)
        }

        function test_openingPopup() {
            mouseClick(controlUnderTest)
            const popup = findChild(controlUnderTest, "dappsListPopup")
            compare(popup.visible, true)
            compare(fuzzyCompare(popup.x, controlUnderTest.width - popup.width, 1))
            compare(popup.y, controlUnderTest.height + 4)
            compare(popup.width, 312)
            verify(popup.height > 0)
            compare(controlUnderTest.dappListRequestedSpy.count, 1)

            const background = findChild(controlUnderTest, "dappsBackground")
            compare(background.active, true)

            mouseClick(controlUnderTest)
            compare(popup.visible, false)
            compare(background.active, false)
        }

        function test_hoverState() {
            const background = findChild(controlUnderTest, "dappsBackground")
            compare(background.active, false)

            mouseMove(controlUnderTest, controlUnderTest.width/2, controlUnderTest.height/2)
            compare(background.active, true)
            compare(controlUnderTest.hovered, true)
            const dappTooltip = findChild(controlUnderTest, "dappTooltip")
            wait(dappTooltip.delay + 50)
            compare(dappTooltip.visible, true)
            compare(dappTooltip.text, "dApp connections")
            verify(dappTooltip.width > 0)
            verify(dappTooltip.height > 0)
            verify(dappTooltip.y > controlUnderTest.height)

            mouseMove(root, 0, 0)
            verify(!background.active)
            verify(!dappTooltip.visible)
        }

        function test_clickConnect() {
            mouseClick(controlUnderTest)
            waitForRendering(controlUnderTest, 200)


            const connectButton = findChild(controlUnderTest, "connectDappButton")
            verify(!!connectButton)

            mouseClick(connectButton)
            compare(controlUnderTest.connectDappSpy.count, 1)
        }

        function test_disconnect() {
            controlUnderTest.model.append({name: "Test dApp 1", url: "https://dapp.test/1", iconUrl: "https://se-sdk-dapp.vercel.app/assets/eip155:1.png", connectorBadge: "status", topic: "https://dapp.test/1"})
            mouseClick(controlUnderTest)
            waitForRendering(controlUnderTest, 200)

            const dapplist = findChild(controlUnderTest, "dappsListPopup")
            const disconnectButton = findChild(dapplist.contentItem, "disconnectDappButton")
            verify(!!disconnectButton)

            mouseClick(disconnectButton)
            compare(controlUnderTest.disconnectDappSpy.count, 1)
        }
    }
}

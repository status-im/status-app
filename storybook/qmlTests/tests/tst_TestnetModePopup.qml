import QtQuick
import QtTest

import StatusQ.Controls

import shared.popups

import utils

Item {
    id: root
    width: 600
    height: 600

    property bool areTestNetworksEnabled: false

    Component {
        id: componentUnderTest
        TestnetModePopup {
            anchors.centerIn: parent
            areTestNetworksEnabled: root.areTestNetworksEnabled
            onToggleTestnetRequested: (enabled) => root.areTestNetworksEnabled = enabled
        }
    }

    SignalSpy {
        id: toastSpy
        target: Global
        signalName: "displayToastMessage"
    }

    SignalSpy {
        id: toggleSpy
        signalName: "toggleTestnetRequested"
    }

    TestCase {
        name: "TestnetModePopup"
        when: windowShown

        property var controlUnderTest: null

        function init() {
            root.areTestNetworksEnabled = false
            toastSpy.clear()
            toggleSpy.clear()
        }

        function cleanup() {
            controlUnderTest = null
        }

        function openPopup() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            toggleSpy.target = controlUnderTest
            toggleSpy.clear()
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            return controlUnderTest
        }

        function test_confirm_turn_on_and_off() {
            const onPopup = openPopup()
            compare(onPopup.title, "Turn on testnet mode")
            compare(onPopup.acceptBtn.type, StatusBaseButton.Type.Warning)

            mouseClick(onPopup.acceptBtn)
            tryCompare(toggleSpy, "count", 1)
            compare(toggleSpy.signalArguments[0][0], true)
            tryCompare(root, "areTestNetworksEnabled", true)
            tryCompare(toastSpy, "count", 1)
            compare(toastSpy.signalArguments[0][0], "Testnet mode turned on")

            toastSpy.clear()

            const offPopup = openPopup()
            compare(offPopup.title, "Turn off testnet mode")
            compare(offPopup.acceptBtn.type, StatusBaseButton.Type.Normal)

            mouseClick(offPopup.acceptBtn)
            tryCompare(toggleSpy, "count", 1)
            compare(toggleSpy.signalArguments[0][0], false)
            tryCompare(root, "areTestNetworksEnabled", false)
            tryCompare(toastSpy, "count", 1)
            compare(toastSpy.signalArguments[0][0], "Testnet mode turned off")
        }

        function test_close_keeps_disabled() {
            const popup = openPopup()
            popup.close()
            tryCompare(popup, "opened", false)
            compare(toggleSpy.count, 0)
            verify(!root.areTestNetworksEnabled)
            compare(toastSpy.count, 0)
        }

        function test_cancel_keeps_enabled() {
            root.areTestNetworksEnabled = true
            const popup = openPopup()
            mouseClick(popup.cancelBtn)
            tryCompare(popup, "opened", false)
            compare(toggleSpy.count, 0)
            verify(root.areTestNetworksEnabled)
            compare(toastSpy.count, 0)
        }
    }
}

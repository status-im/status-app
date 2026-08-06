import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 400
    height: 200

    Component {
        id: componentUnderTest
        StatusStickerButton {
            packPrice: 0
            isInstalled: false
            isBought: false
            isPending: false
            greyedOut: false
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusStickerButton"
        when: windowShown

        property StatusStickerButton controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
        }

        function test_free_emits_installClicked() {
            controlUnderTest.packPrice = 0
            signalSpy.setup(controlUnderTest, "installClicked")

            mouseClick(controlUnderTest)

            compare(signalSpy.count, 1)
        }

        function test_paid_emits_buyClicked() {
            controlUnderTest.packPrice = 100
            controlUnderTest.isBought = false
            signalSpy.setup(controlUnderTest, "buyClicked")

            mouseClick(controlUnderTest)

            compare(signalSpy.count, 1)
        }

        function test_installed_emits_uninstallClicked() {
            controlUnderTest.isInstalled = true
            signalSpy.setup(controlUnderTest, "uninstallClicked")

            mouseClick(controlUnderTest)

            compare(signalSpy.count, 1)
        }

        function test_greyedOut_does_not_emit() {
            controlUnderTest.packPrice = 0
            controlUnderTest.greyedOut = true
            signalSpy.setup(controlUnderTest, "installClicked")

            mouseClick(controlUnderTest)

            compare(signalSpy.count, 0)
        }
    }
}

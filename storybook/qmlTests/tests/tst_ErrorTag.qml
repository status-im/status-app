import QtQuick
import QtTest

import shared.controls

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        ErrorTag {
            anchors.centerIn: parent
            text: "Not enough ETH to pay gas fees"
        }
    }

    SignalSpy {
        id: signalSpy
        target: controlUnderTest
        signalName: "buttonClicked"
    }

    property ErrorTag controlUnderTest: null

    TestCase {
        name: "ErrorTag"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            signalSpy.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_noDefaultButton() {
            verify(!!controlUnderTest)
            const button = findChild(controlUnderTest, "rightComponentButton")
            compare(button, null)
        }

        function test_correctWidthWithButtonOrWithout() {
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            const origWidth = controlUnderTest.width
            controlUnderTest.buttonText = "Add assets"
            controlUnderTest.buttonVisible = true
            waitForRendering(controlUnderTest)
            const widthWithButton = controlUnderTest.width
            verify(widthWithButton > origWidth)
            controlUnderTest.buttonVisible = false
            waitForRendering(controlUnderTest)
            verify(controlUnderTest.width < widthWithButton)
        }

        function test_buttonClick() {
            verify(!!controlUnderTest)
            controlUnderTest.buttonText = "Add assets"
            controlUnderTest.buttonVisible = true
            const button = findChild(controlUnderTest, "rightComponentButton")
            verify(!!button)
            tryCompare(button, "visible", true)
            waitForRendering(controlUnderTest)
            mouseClick(button)
            tryCompare(signalSpy, "count", 1)
        }

        function test_loadingNotClickable()  {
            verify(!!controlUnderTest)
            controlUnderTest.loading = true
            const button = findChild(controlUnderTest, "rightComponentButton")
            compare(button, null)
            tryCompare(signalSpy, "count", 0)
        }
    }
}

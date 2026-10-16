import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import utils


Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        NetworkSelectItemDelegate {
            anchors.centerIn: parent
            text: "Ethereum"
            icon.source: Assets.svg("network/ethereum")
        }
    }

    SignalSpy {
        id: toggledSpy
        target: controlUnderTest
        signalName: "toggled"
    }

    SignalSpy {
        id: checkStateChangedSpy
        target: controlUnderTest
        signalName: "checkStateChanged"
    }

    property NetworkSelectItemDelegate controlUnderTest: null
    property int externalCheckState: Qt.Unchecked

    TestCase {
        name: "NetworkSelectItemDelegate"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            toggledSpy.clear()
            checkStateChangedSpy.clear()
            root.externalCheckState = Qt.Unchecked
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_title() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.text, "Ethereum")
            controlUnderTest.text = "Polygon"
            compare(controlUnderTest.text, "Polygon")
            controlUnderTest.text = ""
            compare(controlUnderTest.text, "")
            controlUnderTest.text = "Ethereum"
        }

        function test_icon() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.icon.source, Assets.svg("network/ethereum"))
            compare(findChild(controlUnderTest, "statusRoundImage").source, Assets.svg("network/ethereum"))
            controlUnderTest.icon.source = Assets.svg("network/polygon")
            compare(controlUnderTest.icon.source, Assets.svg("network/polygon"))
            compare(findChild(controlUnderTest, "statusRoundImage").source, Assets.svg("network/polygon"))
        }

        function test_indicatorConfig() {
            verify(!!controlUnderTest)
            verify(!!findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum"))
            compare(controlUnderTest.showIndicator, true)
            compare(controlUnderTest.indicator.visible, false)

            controlUnderTest.checked = true
            compare(controlUnderTest.indicator.visible, true)

            controlUnderTest.showIndicator = false
            compare(controlUnderTest.indicator.visible, false)

            controlUnderTest.showIndicator = true
            compare(controlUnderTest.indicator.visible, true)
        }

        function test_toggleByClick() {
            verify(!!controlUnderTest)
            mouseClick(controlUnderTest)
            tryCompare(toggledSpy, "count", 1)

            const indicator = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            verify(!!indicator)
            mouseClick(indicator)
            tryCompare(toggledSpy, "count", 2)
            mouseClick(indicator)
            tryCompare(toggledSpy, "count", 3)
        }

        function test_autoCheckStateChanges() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Checked)
            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
            const checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            verify(!!checkBox)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Checked)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
        }

        function test_manualCheckStateChanges() {
            verify(!!controlUnderTest)
            controlUnderTest.nextCheckState = () => controlUnderTest.checkState
            compare(controlUnderTest.checkState, Qt.Unchecked)

            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
            const checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            verify(!!checkBox)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
            compare(toggledSpy.count, 0)

            controlUnderTest.nextCheckState = () => controlUnderTest.checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked

            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Checked)

            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)

            controlUnderTest.nextCheckState = function() {
                return controlUnderTest.checkState === Qt.Unchecked ? Qt.PartiallyChecked :
                       controlUnderTest.checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
            }

            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.PartiallyChecked)
            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Checked)
            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)

            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.PartiallyChecked)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Checked)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
        }

        function test_checkStateBindings() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            compare(root.externalCheckState, Qt.Unchecked)

            controlUnderTest.checkState = Qt.binding(() => root.externalCheckState)
            compare(controlUnderTest.checkState, root.externalCheckState)
            tryCompare(checkStateChangedSpy, "count", 0)

            root.externalCheckState = Qt.Checked
            compare(controlUnderTest.checkState, Qt.Checked)
            tryCompare(checkStateChangedSpy, "count", 1)

            root.externalCheckState = Qt.Unchecked
            compare(controlUnderTest.checkState, Qt.Unchecked)
            tryCompare(checkStateChangedSpy, "count", 2)
        }

        function test_interactiveConfig() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.interactive, true)
            controlUnderTest.interactive = false
            compare(controlUnderTest.checkState, Qt.Unchecked)

            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)

            const checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            verify(!!checkBox)
            mouseClick(checkBox)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)
            compare(toggledSpy.count, 0)

            controlUnderTest.showIndicator = false

            mouseClick(controlUnderTest)
            tryCompare(controlUnderTest, "checkState", Qt.Unchecked)

            // manual selection works
            controlUnderTest.checkState = Qt.Checked
            compare(controlUnderTest.checkState, Qt.Checked)
            controlUnderTest.checkState = Qt.Unchecked
            compare(controlUnderTest.checkState, Qt.Unchecked)
        }

        function test_newIcon() {
            verify(!!controlUnderTest)
            verify(!controlUnderTest.showNewIcon)

            controlUnderTest.showNewIcon = true

            verify(controlUnderTest.showNewIcon)

            const newIcon = findChild(controlUnderTest, "networkSelectionNewIcon_Ethereum")
            verify(newIcon)

            const tooltip = findChild(newIcon, "tooltip")
            verify(tooltip)

            verify(tooltip.text.indexOf("Ethereum") >= 0)

            controlUnderTest.text = "Base"
            verify(tooltip.text.indexOf("Ethereum") === -1)
            verify(tooltip.text.indexOf("Base") >= 0)
        }
    }
}

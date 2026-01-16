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
            title: "Ethereum"
            iconUrl: Assets.svg("network/ethereum")
            onToggled: root.onToggledHandler()
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
    property var onToggledHandler: function(){}
    property int externalCheckState: Qt.Unchecked

    TestCase {
        name: "NetworkSelectItemDelegate"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            toggledSpy.clear()
            checkStateChangedSpy.clear()
            onToggledHandler = function() {}
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_title() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.title, "Ethereum")
            controlUnderTest.title = "Polygon"
            compare(controlUnderTest.title, "Polygon")
            controlUnderTest.title = ""
            compare(controlUnderTest.title, "")
            controlUnderTest.title = "Ethereum"
        }

        function test_icon() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.iconUrl, Assets.svg("network/ethereum"))
            compare(findChild(controlUnderTest, "statusRoundImage").image.source, Assets.svg("network/ethereum"))
            controlUnderTest.iconUrl = Assets.svg("network/polygon")
            compare(controlUnderTest.iconUrl, Assets.svg("network/polygon"))
            compare(findChild(controlUnderTest, "statusRoundImage").image.source, Assets.svg("network/polygon"))
        }

        function test_indicatorConfig() {
            verify(!!controlUnderTest)
            verify(!!findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum"))
            verify(!findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum"))
            compare(controlUnderTest.showIndicator, true)
            compare(controlUnderTest.multiSelection, false)

            //changing to multiselect -> indicator switches to checkbox
            controlUnderTest.multiSelection = true
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)
            verify(!!findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum"))
            verify(!findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum"))

            //changing removing indicator
            controlUnderTest.showIndicator = false
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)
            verify(!findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum"))
            verify(!findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum"))
        }

        function test_toggleByClick() {
            verify(!!controlUnderTest)
            mouseClick(controlUnderTest)
            tryCompare(toggledSpy, "count", 1)

            const image = findChild(controlUnderTest, "statusRoundImage")
            mouseClick(image)
            tryCompare(toggledSpy, "count", 2)

            const radioButton = findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum")
            mouseClick(radioButton)
            tryCompare(toggledSpy, "count", 3)

            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest)
            const checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            mouseClick(checkBox)
            tryCompare(toggledSpy, "count", 4)
        }

        function test_autoCheckStateChanges() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            const radioButton = findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum")
            mouseClick(radioButton)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(radioButton)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            const checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            mouseClick(checkBox)
            waitForItemPolished(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
        }

        function test_manualCheckStateChanges() {
            verify(!!controlUnderTest)
            // checkState is not bound to nextCheckState => no automatic check changes
            controlUnderTest.nextCheckState = Qt.binding(() => controlUnderTest.checkState)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            let radioButton = findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum")
            mouseClick(radioButton)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)
            let checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.multiSelection = false
            waitForItemPolished(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            root.onToggledHandler = function() {
                controlUnderTest.checkState = controlUnderTest.checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
            }

            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Checked)

            radioButton = findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum")
            mouseClick(radioButton)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.multiSelection = true
            root.onToggledHandler = function() {
                controlUnderTest.checkState = controlUnderTest.checkState === Qt.Unchecked ? Qt.PartiallyChecked :
                                                                            controlUnderTest.checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
            }

            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.PartiallyChecked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.PartiallyChecked)
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.Checked)
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.Unchecked)
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
            compare(controlUnderTest.checkState, Qt.Unchecked)

            let radioButton = findChild(controlUnderTest, "networkSelectionRadioButton_Ethereum")
            mouseClick(radioButton)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest)

            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            let checkBox = findChild(controlUnderTest, "networkSelectionCheckbox_Ethereum")
            mouseClick(checkBox)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            controlUnderTest.showIndicator = false

            mouseClick(controlUnderTest)
            compare(controlUnderTest.checkState, Qt.Unchecked)

            mouseMove(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)
            compare(controlUnderTest.sensor.containsMouse, true)

            // manual selection works
            controlUnderTest.checkState = Qt.Checked
            compare(controlUnderTest.checkState, Qt.Checked)
            controlUnderTest.checkState = Qt.Unchecked
            compare(controlUnderTest.checkState, Qt.Unchecked)
        }

        function test_newIcon() {
            verify(!!controlUnderTest)
            verify(!controlUnderTest.showNewIcon)
            verify(!controlUnderTest.statusListItemTitleIcons.active)

            controlUnderTest.showNewIcon = true

            verify(controlUnderTest.showNewIcon)
            verify(controlUnderTest.statusListItemTitleIcons.active)

            const newIcon = findChild(controlUnderTest, "networkSelectionNewIcon_Ethereum")
            verify(newIcon)

            const tooltip = findChild(newIcon, "tooltip")
            verify(tooltip)

            verify(tooltip.text.indexOf("Ethereum") >= 0)

            controlUnderTest.title = "Base"
            verify(tooltip.text.indexOf("Ethereum") === -1)
            verify(tooltip.text.indexOf("Base") >= 0)
        }
    }
}

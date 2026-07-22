import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Wallet.views

import utils

import shared.stores

Item {
    id: root
    width: 600
    height: 600

    readonly property var networksStore: NetworksStore{}

    Component {
        id: componentUnderTest
        NetworkSelectorView {
            anchors.centerIn: parent
            model: root.networksStore.allNetworks
        }
    }

    SignalSpy {
        id: toggleNetworkSpy
        target: controlUnderTest
        signalName: "toggleNetwork"
    }

    SignalSpy {
        id: selectionChangedSpy
        target: controlUnderTest
        signalName: "onSelectionChanged"
    }

    property NetworkSelectorView controlUnderTest: null

    TestCase {
        name: "NetworkSelectorView"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            toggleNetworkSpy.clear()
            selectionChangedSpy.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_defaultConfiguration() {
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            // Default configuration:
            // - model is not empty
            // - showIndicator is true
            // - multiSelection is false
            // - interactive is true
            // - selection has length 1. This is because the single selection mode is enabled by default

            verify(controlUnderTest.model.count > 0)
            verify(controlUnderTest.showIndicator)
            verify(!controlUnderTest.multiSelection)
            verify(controlUnderTest.interactive)
            verify(controlUnderTest.selection.length === 1)
        }

        function test_defaultDelegate() {
            // iterate the model and check:
            // - a delegate is created for each item
            // - the delegate has the correct chain name
            // - the delegate has the correct icon url
            // - the delegate has the correct show indicator value
            // - the delegate has the correct multi selection value
            // - the delegate has the correct check state

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const model = controlUnderTest.model.get(i)
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                verify(!!delegate)
                compare(delegate.title, model.chainName)
                compare(delegate.iconUrl, Assets.svg(model.iconUrl))
                compare(delegate.showIndicator, controlUnderTest.showIndicator)
                compare(delegate.multiSelection, controlUnderTest.multiSelection)
                compare(delegate.checkState, controlUnderTest.selection.includes(model.chainId) ? Qt.Checked : Qt.Unchecked)
            }

            controlUnderTest = createTemporaryObject(componentUnderTest, root, {multiSelection: true})

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const model = controlUnderTest.model.get(i)
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                compare(delegate.showIndicator, controlUnderTest.showIndicator)
                compare(delegate.multiSelection, controlUnderTest.multiSelection)
                compare(delegate.checkState, Qt.Unchecked)
            }
        }

        function test_selectionBindingsSingleSelection() {
            // 1. toggle by click
            // 2. toggle by updating the selection property
            // 3. toggle by click
            // 4. toggle by updating the selection property

            let delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(1).chainName)

            // 1. toggle by click
            mouseClick(delegate)
            compare(toggleNetworkSpy.count, 1)
            compare(selectionChangedSpy.count, 1)
            compare(delegate.checkState, Qt.Checked)

            // 2. toggle by updating the selection property
            controlUnderTest.selection = [controlUnderTest.model.get(2).chainId]
            compare(toggleNetworkSpy.count, 1)
            compare(selectionChangedSpy.count, 2)
            compare(controlUnderTest.selection.length, 1)
            compare(controlUnderTest.selection[0], controlUnderTest.model.get(2).chainId)
            compare(delegate.checkState, Qt.Unchecked)
            delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(2).chainName)
            compare(delegate.checkState, Qt.Checked)

            // 3. toggle by click
            const newSelectionDelegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(1).chainName)
            mouseClick(newSelectionDelegate)
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 3)
            compare(delegate.checkState, Qt.Unchecked)
            compare(newSelectionDelegate.checkState, Qt.Checked)

            // 4. toggle by updating the selection property
            controlUnderTest.selection = [controlUnderTest.model.get(2).chainId]
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 4)
            compare(controlUnderTest.selection.length, 1)
            compare(controlUnderTest.selection[0], controlUnderTest.model.get(2).chainId)
            compare(delegate.checkState, Qt.Checked)
            compare(newSelectionDelegate.checkState, Qt.Unchecked)
        }

        function test_selectionBindingMultiSelection() {
            // 1. toggle by click
            // 2. toggle by updating the selection property
            // 3. toggle by click
            // 4. toggle by updating the selection property

            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest)

            let delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(1).chainName)

            // 1. toggle by click
            mouseClick(delegate)
            compare(toggleNetworkSpy.count, 1)
            compare(selectionChangedSpy.count, 1)
            compare(delegate.checkState, Qt.Checked)

            // 2. toggle by updating the selection property
            controlUnderTest.selection = [controlUnderTest.model.get(1).chainId, controlUnderTest.model.get(2).chainId]
            compare(toggleNetworkSpy.count, 1)
            compare(selectionChangedSpy.count, 2)
            compare(controlUnderTest.selection.length, 2)
            verify(controlUnderTest.selection.includes(controlUnderTest.model.get(1).chainId))
            verify(controlUnderTest.selection.includes(controlUnderTest.model.get(2).chainId))
            compare(delegate.checkState, Qt.Checked)
            delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(2).chainName)
            compare(delegate.checkState, Qt.Checked)

            // 3. toggle by click
            const newSelectionDelegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(1).chainName)
            mouseClick(newSelectionDelegate)
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 3)
            compare(delegate.checkState, Qt.Checked)
            compare(newSelectionDelegate.checkState, Qt.Unchecked)
            mouseClick(newSelectionDelegate)
            compare(newSelectionDelegate.checkState, Qt.Checked)

            // 4. toggle by updating the selection property
            controlUnderTest.selection = [controlUnderTest.model.get(2).chainId]
            compare(toggleNetworkSpy.count, 3)
            compare(selectionChangedSpy.count, 5)
            compare(controlUnderTest.selection.length, 1)
            compare(controlUnderTest.selection[0], controlUnderTest.model.get(2).chainId)
            compare(delegate.checkState, Qt.Checked)
            compare(newSelectionDelegate.checkState, Qt.Unchecked)
            mouseClick(delegate)
            compare(toggleNetworkSpy.count, 4)
            compare(delegate.checkState, Qt.Unchecked)
            compare(controlUnderTest.selection.length, 0)

            // 5. select all by click
            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(i).chainName)
                mouseClick(delegate)
            }

            compare(controlUnderTest.selection.length, controlUnderTest.model.count)
            compare(toggleNetworkSpy.count, controlUnderTest.model.count + 4)
            toggleNetworkSpy.clear()
            selectionChangedSpy.clear()

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(i).chainName)
                compare(delegate.checkState, Qt.PartiallyChecked)
            }

            // 6. set the selection to all selected
            const selection = [...controlUnderTest.selection]
            controlUnderTest.selection = selection

            compare(toggleNetworkSpy.count, 0)
            compare(selectionChangedSpy.count, 1)

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(i).chainName)
                compare(delegate.checkState, Qt.PartiallyChecked)
            }

            // 7. deselect and select again the same item
            mouseClick(findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(0).chainName))
            compare(toggleNetworkSpy.count, 1)
            compare(selectionChangedSpy.count, 2)
            compare(controlUnderTest.selection.length, controlUnderTest.model.count - 1)
            compare(findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(0).chainName).checkState, Qt.Unchecked)
            
            mouseClick(findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(0).chainName))
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 3)
            compare(controlUnderTest.selection.length, controlUnderTest.model.count)

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(i).chainName)
                compare(delegate.checkState, Qt.PartiallyChecked)
            }

            // 8. deselect one by setting the selection and select all again
            let selection2 = [...controlUnderTest.selection]
            const deletedId = selection2.splice(0, 1)

            controlUnderTest.selection = selection2
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 4)
            compare(controlUnderTest.selection.length, controlUnderTest.model.count - 1)

            for (var i = 1; i < controlUnderTest.model.count; i++) {
                const model = controlUnderTest.model.get(i)
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)
                compare(delegate.checkState, model.chainId === deletedId[0] ? Qt.Unchecked : Qt.Checked)
            }

            selection2 = [...controlUnderTest.selection, deletedId[0]]
            controlUnderTest.selection = selection2
            compare(toggleNetworkSpy.count, 2)
            compare(selectionChangedSpy.count, 5)
            compare(controlUnderTest.selection.length, controlUnderTest.model.count)

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + controlUnderTest.model.get(i).chainName)
                compare(delegate.checkState, Qt.PartiallyChecked)
            }
        }

        function test_noIndicatorConfig() {
            controlUnderTest.showIndicator = false
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)

            for (let multiSelect = 0; multiSelect < 2; multiSelect++) {
                controlUnderTest.multiSelection = multiSelect
                waitForRendering(controlUnderTest)
                waitForItemPolished(controlUnderTest)

                for (var i = 0; i < controlUnderTest.model.count; i++) {
                    const model = controlUnderTest.model.get(i)
                    const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                    compare(delegate.showIndicator, controlUnderTest.showIndicator)

                    const checkBox = findChild(delegate, "networkSelectionCheckbox_" + model.chainName)
                    const radioButton = findChild(delegate, "networkSelectionRadioButton_" + model.chainName)

                    verify(!checkBox)
                    verify(!radioButton)
                }
            }

            controlUnderTest.showIndicator = true
            waitForRendering(controlUnderTest)
            waitForItemPolished(controlUnderTest)

            for (let multiSelect = 0; multiSelect < 2; multiSelect++) {
                controlUnderTest.multiSelection = multiSelect
                waitForRendering(controlUnderTest)
                waitForItemPolished(controlUnderTest)

                for (var i = 0; i < controlUnderTest.model.count; i++) {
                    const model = controlUnderTest.model.get(i)
                    const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                    compare(delegate.showIndicator, controlUnderTest.showIndicator)

                    const checkBox = findChild(delegate, "networkSelectionCheckbox_" + model.chainName)
                    const radioButton = findChild(delegate, "networkSelectionRadioButton_" + model.chainName)
                    if (multiSelect) {
                        verify(!!checkBox)
                        verify(!radioButton)
                    } else {
                        verify(!checkBox)
                        verify(!!radioButton)
                    }
                }
            }
        }

        function test_interactiveConfig() {
            controlUnderTest.interactive = false

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const model = controlUnderTest.model.get(i)
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                mouseClick(delegate)
                compare(toggleNetworkSpy.count, 0)
                compare(selectionChangedSpy.count, 0)
            }

            controlUnderTest.interactive = true

            for (var i = 0; i < controlUnderTest.model.count; i++) {
                const model = controlUnderTest.model.get(i)
                const delegate = findChild(controlUnderTest, "networkSelectorDelegate_" + model.chainName)

                mouseClick(delegate)
                compare(toggleNetworkSpy.count, i + 1)
                // i == 0 re-clicks the auto-selected first chain: toggleNetwork
                // fires but the selection content does not change
                compare(selectionChangedSpy.count, i)
            }
        }
    }
}

import QtQuick
import QtTest

import AppLayouts.Wallet.popups

import utils

import Models

Item {
    id: root
    width: 600
    height: 600

    Component {
        id: componentUnderTest
        NetworkSelectPopup {
            directParent: root
            relativeX: parent.width/2 - width/2
            relativeY: parent.height/2 - height/2
            flatNetworks: NetworksModel.flatNetworks
        }
    }

    SignalSpy {
        id: selectionChangedSpy
        target: controlUnderTest
        signalName: "onSelectionChanged"
    }

    property NetworkSelectPopup controlUnderTest: null

    TestCase {
        name: "NetworkSelectPopup"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            selectionChangedSpy.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.width, 300)
            compare(controlUnderTest.height, controlUnderTest.contentHeight + controlUnderTest.padding * 2)
        }

        function test_selectionBindings() {
            //single selection - select using the selectio property
            compare(controlUnderTest.multiSelection, false)
            controlUnderTest.selection = [controlUnderTest.flatNetworks.get(0).chainId]
            compare(controlUnderTest.selection, [controlUnderTest.flatNetworks.get(0).chainId])
            compare(selectionChangedSpy.count, 1)

            //single selection - select using the view
            const secondDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + controlUnderTest.flatNetworks.get(1).chainName)
            mouseClick(secondDelegate)
            compare(controlUnderTest.selection, [controlUnderTest.flatNetworks.get(1).chainId])
            compare(selectionChangedSpy.count, 2)

            // multi selection - select using selection property
            controlUnderTest.open()
            controlUnderTest.multiSelection = true
            controlUnderTest.selection = [controlUnderTest.flatNetworks.get(0).chainId, controlUnderTest.flatNetworks.get(1).chainId]
            compare(controlUnderTest.selection, [controlUnderTest.flatNetworks.get(0).chainId, controlUnderTest.flatNetworks.get(1).chainId])
            compare(selectionChangedSpy.count, 3)

            // multi selection - select using the view
            const thirdDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + controlUnderTest.flatNetworks.get(2).chainName)
            mouseClick(thirdDelegate)
            compare(controlUnderTest.selection.sort(), [controlUnderTest.flatNetworks.get(0).chainId, controlUnderTest.flatNetworks.get(1).chainId, controlUnderTest.flatNetworks.get(2).chainId].sort())
            compare(selectionChangedSpy.count, 4)
        }

        function test_closeAfterSingleSelection() {
            compare(controlUnderTest.multiSelection, false)
            const secondDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + controlUnderTest.flatNetworks.get(1).chainName)
            mouseClick(secondDelegate)
            compare(controlUnderTest.opened, false)

            controlUnderTest.open()
            controlUnderTest.multiSelection = true
            const thirdDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + controlUnderTest.flatNetworks.get(2).chainName)
            mouseClick(thirdDelegate)
            compare(controlUnderTest.opened, true)
        }

        function test_allNetworksSelection() {
            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest.contentItem.item)

            const allNetworksDelegate = findChild(controlUnderTest.contentItem, qsTr("All Networks"))
            verify(!!allNetworksDelegate)
            compare(allNetworksDelegate.checked, false)

            mouseClick(allNetworksDelegate)
            tryCompare(controlUnderTest, "selection", allChainIds())
            compare(allNetworksDelegate.checked, true)
            compare(controlUnderTest.opened, true)

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                const network = controlUnderTest.flatNetworks.get(i)
                const delegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + network.chainName)
                verify(!!delegate)
                compare(delegate.checked, true)
            }

            const secondNetwork = controlUnderTest.flatNetworks.get(1)
            const secondDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + secondNetwork.chainName)
            verify(!!secondDelegate)
            mouseClick(secondDelegate)
            tryCompare(allNetworksDelegate, "checked", false)
            compare(controlUnderTest.selection, [secondNetwork.chainId])

            mouseClick(allNetworksDelegate)
            tryCompare(allNetworksDelegate, "checked", true)
            compare([...controlUnderTest.selection].sort(), allChainIds().sort())

            mouseClick(allNetworksDelegate)
            tryCompare(controlUnderTest, "selection", [controlUnderTest.flatNetworks.get(0).chainId])
            compare(allNetworksDelegate.checked, false)
        }

        function test_individualSelectionWhenAllSelected_data() {
            const rows = []
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++) {
                const network = NetworksModel.flatNetworks.get(i)
                rows.push({tag: network.chainName + " initial", index: i, initiallyMultiSelection: true})
                rows.push({tag: network.chainName + " switched", index: i, initiallyMultiSelection: false})
            }
            return rows
        }

        function test_individualSelectionWhenAllSelected(data) {
            const selection = allChainIds()
            controlUnderTest.close()
            controlUnderTest = createTemporaryObject(componentUnderTest, root,
                {multiSelection: data.initiallyMultiSelection,
                 selection: data.initiallyMultiSelection ? selection : [selection[data.index]]})
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            controlUnderTest.multiSelection = true
            controlUnderTest.selection = allChainIds()
            waitForItemPolished(controlUnderTest.contentItem.item)

            const network = controlUnderTest.flatNetworks.get(data.index)
            const delegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + network.chainName)
            const allNetworksDelegate = findChild(controlUnderTest.contentItem, qsTr("All Networks"))
            verify(!!delegate)
            verify(!!allNetworksDelegate)
            compare(allNetworksDelegate.checked, true)
            selectionChangedSpy.clear()

            mouseClick(delegate)
            tryCompare(controlUnderTest, "selection", [network.chainId])
            tryCompare(selectionChangedSpy, "count", 1)
            tryCompare(allNetworksDelegate, "checked", false)
            compare(controlUnderTest.opened, true)

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                const item = controlUnderTest.flatNetworks.get(i)
                const networkDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + item.chainName)
                verify(!!networkDelegate)
                tryCompare(networkDelegate, "checked", item.chainId === network.chainId)
            }

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                mouseClick(allNetworksDelegate)
                tryCompare(allNetworksDelegate, "checked", true)
                const item = controlUnderTest.flatNetworks.get(i)
                const networkDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + item.chainName)
                verify(!!networkDelegate)
                mouseClick(networkDelegate)
                tryCompare(controlUnderTest, "selection", [item.chainId])
                tryCompare(networkDelegate, "checked", true)
                tryCompare(allNetworksDelegate, "checked", false)

                const otherNetwork = controlUnderTest.flatNetworks.get((i + 1) % controlUnderTest.flatNetworks.count)
                const otherDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + otherNetwork.chainName)
                verify(!!otherDelegate)
                mouseClick(otherDelegate)
                tryCompare(controlUnderTest, "selection", [item.chainId, otherNetwork.chainId])
                mouseClick(otherDelegate)
                tryCompare(controlUnderTest, "selection", [item.chainId])
            }
        }

        function test_programmaticSelectionWhenAllSelected() {
            controlUnderTest.multiSelection = true
            controlUnderTest.selection = allChainIds()
            const view = findChild(controlUnderTest.contentItem, "networkSelectorList")
            verify(!!view)

            const selection = allChainIds().slice(1)
            controlUnderTest.selection = selection
            tryCompare(view, "selection", selection)
            compare(controlUnderTest.selection, selection)
        }

        function allChainIds() {
            const ids = []
            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++)
                ids.push(controlUnderTest.flatNetworks.get(i).chainId)
            return ids
        }
    }
}

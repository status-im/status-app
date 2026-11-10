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
            onToggleNetwork: (chainId, index) => root.toggleNetworkHandler(chainId, index)
        }
    }

    Component {
        id: manyNetworksComponent
        ListModel {}
    }

    SignalSpy {
        id: selectionChangedSpy
        target: controlUnderTest
        signalName: "onSelectionChanged"
    }

    property NetworkSelectPopup controlUnderTest: null
    property var toggleNetworkHandler: function(chainId, index) {}

    SignalSpy {
        id: toggleNetworkSpy
        target: controlUnderTest
        signalName: "toggleNetwork"
    }

    TestCase {
        name: "NetworkSelectPopup"
        when: windowShown

        function init() {
            root.toggleNetworkHandler = function(chainId, index) {}
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            selectionChangedSpy.clear()
            toggleNetworkSpy.clear()
        }

        function test_manyNetworksScrollWithinTheWindow() {
            const model = createTemporaryObject(manyNetworksComponent, root)
            for (let i = 0; i < 20; ++i)
                model.append({ chainId: 1000 + i, chainName: "Chain" + i, iconUrl: "network/ethereum",
                               isTest: false, layer: 2, communitiesSupported: true })
            controlUnderTest.close()
            controlUnderTest = createTemporaryObject(componentUnderTest, root,
                                                     { flatNetworks: model, multiSelection: true,
                                                       showManageNetworksButton: true })
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            waitForRendering(controlUnderTest.contentItem)

            verify(controlUnderTest.height <= root.height)

            const list = findChild(controlUnderTest.contentItem, "networkSelectorList")
            verify(!!list)
            verify(list.height < list.contentHeight)

            const manageButton = findChild(controlUnderTest.contentItem, "manageNetworksButton")
            verify(!!manageButton)
            const bottom = manageButton.mapToItem(controlUnderTest.contentItem, 0, manageButton.height).y
            verify(bottom <= controlUnderTest.contentItem.height,
                   "button bottom %1, content height %2".arg(bottom).arg(controlUnderTest.contentItem.height))
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

        function test_closeAfterClickingCheckedNetwork_data() {
            const rows = []
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++) {
                const network = NetworksModel.flatNetworks.get(i)
                rows.push({tag: network.chainName, chainId: network.chainId, chainName: network.chainName})
            }
            return rows
        }

        function test_closeAfterClickingCheckedNetwork(data) {
            compare(controlUnderTest.multiSelection, false)
            controlUnderTest.selection = [data.chainId]
            const delegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + data.chainName)
            verify(!!delegate)
            tryCompare(delegate, "checked", true)
            selectionChangedSpy.clear()
            toggleNetworkSpy.clear()

            mouseClick(delegate)
            tryCompare(controlUnderTest, "visible", false)
            tryCompare(controlUnderTest, "selection", [data.chainId])
            tryCompare(selectionChangedSpy, "count", 0)
            tryCompare(toggleNetworkSpy, "count", 0)
        }

        function test_allNetworksSelection() {
            controlUnderTest.multiSelection = true
            waitForItemPolished(controlUnderTest.contentItem.item)

            const allNetworksDelegate = findChild(controlUnderTest.contentItem, "selectAllButton")
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

        }

        function test_selectAllEmitsToggles_data() {
            return [
                {tag: "empty", selectedIndices: [], roundTrip: false},
                {tag: "partial", selectedIndices: [0, 2], roundTrip: false},
                {tag: "store round trip", selectedIndices: [0, 2], roundTrip: true}
            ]
        }

        function test_selectAllEmitsToggles(data) {
            controlUnderTest.multiSelection = true
            const chainIds = allChainIds()
            let storeSelection = data.selectedIndices.map(index => chainIds[index])
            controlUnderTest.selection = [...storeSelection]
            const expectedIndices = chainIds.map((chainId, index) => index)
                .filter(index => !data.selectedIndices.includes(index))
            if (data.roundTrip) {
                root.toggleNetworkHandler = function(chainId, index) {
                    verify(controlUnderTest.selection.includes(chainId))
                    storeSelection = [...storeSelection, chainId]
                    controlUnderTest.selection = [...storeSelection]
                }
            }
            waitForItemPolished(controlUnderTest.contentItem.item)
            const allNetworksDelegate = findChild(controlUnderTest.contentItem, "selectAllButton")
            verify(!!allNetworksDelegate)
            toggleNetworkSpy.clear()

            mouseClick(allNetworksDelegate)
            tryCompare(toggleNetworkSpy, "count", expectedIndices.length)
            compare([...controlUnderTest.selection].sort(), [...chainIds].sort())
            tryCompare(allNetworksDelegate, "checked", true)
            for (let i = 0; i < expectedIndices.length; i++) {
                const index = expectedIndices[i]
                compare(toggleNetworkSpy.signalArguments[i][0], chainIds[index])
                compare(toggleNetworkSpy.signalArguments[i][1], index)
            }
            if (data.roundTrip)
                compare([...storeSelection].sort(), [...chainIds].sort())

            toggleNetworkSpy.clear()
            selectionChangedSpy.clear()
            mouseClick(allNetworksDelegate)
            tryCompare(toggleNetworkSpy, "count", 0)
            compare(selectionChangedSpy.count, 0)
            compare([...controlUnderTest.selection].sort(), [...chainIds].sort())
            tryCompare(allNetworksDelegate, "checked", true)
        }

        function test_selectAllAfterIndividualToggle() {
            controlUnderTest.multiSelection = true
            controlUnderTest.selection = allChainIds()
            waitForItemPolished(controlUnderTest.contentItem.item)
            const allNetworksDelegate = findChild(controlUnderTest.contentItem, "selectAllButton")
            verify(!!allNetworksDelegate)
            const secondNetwork = controlUnderTest.flatNetworks.get(1)
            const secondDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + secondNetwork.chainName)
            verify(!!secondDelegate)
            mouseClick(secondDelegate)
            tryCompare(allNetworksDelegate, "checked", false)
            compare(controlUnderTest.selection, allChainIds().filter(chainId => chainId !== secondNetwork.chainId))

            mouseClick(allNetworksDelegate)
            tryCompare(allNetworksDelegate, "checked", true)
            compare([...controlUnderTest.selection].sort(), allChainIds().sort())

            mouseClick(allNetworksDelegate)
            tryCompare(controlUnderTest, "selection", allChainIds())
            tryCompare(allNetworksDelegate, "checked", true)
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
            const allNetworksDelegate = findChild(controlUnderTest.contentItem, "selectAllButton")
            verify(!!delegate)
            verify(!!allNetworksDelegate)
            compare(allNetworksDelegate.checked, true)
            selectionChangedSpy.clear()

            mouseClick(delegate)
            tryCompare(controlUnderTest, "selection", allChainIds().filter(chainId => chainId !== network.chainId))
            tryCompare(selectionChangedSpy, "count", 1)
            tryCompare(allNetworksDelegate, "checked", false)
            compare(controlUnderTest.opened, true)

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                const item = controlUnderTest.flatNetworks.get(i)
                const networkDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + item.chainName)
                verify(!!networkDelegate)
                tryCompare(networkDelegate, "checked", item.chainId !== network.chainId)
            }

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                mouseClick(allNetworksDelegate)
                tryCompare(allNetworksDelegate, "checked", true)
                const item = controlUnderTest.flatNetworks.get(i)
                const networkDelegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + item.chainName)
                verify(!!networkDelegate)
                mouseClick(networkDelegate)
                tryVerify(() => JSON.stringify([...controlUnderTest.selection].sort())
                          === JSON.stringify(allChainIds().filter(chainId => chainId !== item.chainId).sort()))
                tryCompare(networkDelegate, "checked", false)
                tryCompare(allNetworksDelegate, "checked", false)

                mouseClick(networkDelegate)
                tryCompare(networkDelegate, "checked", true)
                tryCompare(allNetworksDelegate, "checked", true)
                compare([...controlUnderTest.selection].sort(), allChainIds().sort())
            }
        }

        function test_deselectAllIndividually() {
            controlUnderTest.multiSelection = true
            controlUnderTest.selection = allChainIds()
            waitForItemPolished(controlUnderTest.contentItem.item)
            const allNetworksDelegate = findChild(controlUnderTest.contentItem, "selectAllButton")
            verify(!!allNetworksDelegate)

            for (let i = 0; i < controlUnderTest.flatNetworks.count; i++) {
                const network = controlUnderTest.flatNetworks.get(i)
                const delegate = findChild(controlUnderTest.contentItem, "networkSelectorDelegate_" + network.chainName)
                verify(!!delegate)
                mouseClick(delegate)
                tryCompare(delegate, "checked", false)
                tryCompare(controlUnderTest, "selection", allChainIds().slice(i + 1))
                tryCompare(allNetworksDelegate, "checked", false)
            }

            mouseClick(allNetworksDelegate)
            tryCompare(controlUnderTest, "selection", allChainIds())
            tryCompare(allNetworksDelegate, "checked", true)
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

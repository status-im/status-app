import QtQuick
import QtTest

import AppLayouts.Wallet.controls

import Models

Item {
    id: root
    width: 600
    height: 600

    // stand-in for RightTabView's chainIdsAggregator
    property var enabledChainIds: []

    // stand-in for SwapInputPanel-style store round-trip
    property int storeChainId: 0

    Component {
        id: singleSelectionComponent
        NetworkFilter {
            flatNetworks: NetworksModel.flatNetworks
            multiSelection: false
            // literal binding on purpose: internal writes must not detach it
            selection: [root.storeChainId]
            onSelectionChanged: {
                if (selection[0] !== undefined && selection[0] !== root.storeChainId)
                    root.storeChainId = selection[0]
            }
        }
    }

    Component {
        id: componentUnderTest
        NetworkFilter {
            flatNetworks: NetworksModel.flatNetworks
            multiSelection: true

            Binding on selection {
                value: root.enabledChainIds
            }
        }
    }

    property NetworkFilter controlUnderTest: null

    TestCase {
        name: "NetworkFilterRepro"
        when: windowShown

        function allChainIds() {
            const ids = []
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                ids.push(NetworksModel.flatNetworks.get(i).chainId)
            return ids
        }

        function test_multiSelectionBindingPush() {
            root.enabledChainIds = allChainIds()
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            // the pushed multi selection must survive creation
            compare(controlUnderTest.selection.length, root.enabledChainIds.length)

            // store-side change must be reflected (RightTabView flow)
            root.enabledChainIds = [allChainIds()[1]]
            compare(controlUnderTest.selection, root.enabledChainIds)
        }

        function test_multiSelectionLatePush() {
            root.enabledChainIds = []
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            root.enabledChainIds = allChainIds()
            compare(controlUnderTest.selection.length, root.enabledChainIds.length)
        }

        // live app models populate late and reset; selection must survive
        function test_selectionSurvivesModelReset() {
            root.enabledChainIds = allChainIds()

            const dynamicModel = createTemporaryQmlObject(
                "import QtQuick; ListModel {}", root)
            controlUnderTest = createTemporaryObject(componentUnderTest, root,
                {flatNetworks: dynamicModel})
            verify(!!controlUnderTest)

            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            compare(controlUnderTest.selection.length, root.enabledChainIds.length)

            // model reset (count -> 0 -> N)
            dynamicModel.clear()
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            compare(controlUnderTest.selection.length, root.enabledChainIds.length)
        }

        function test_singleSelectionSurvivesModelReset() {
            const dynamicModel = createTemporaryQmlObject(
                "import QtQuick; ListModel {}", root)
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            root.enabledChainIds = [allChainIds()[1]]
            controlUnderTest = createTemporaryObject(componentUnderTest, root,
                {flatNetworks: dynamicModel, multiSelection: false})
            verify(!!controlUnderTest)
            compare(controlUnderTest.selection, [allChainIds()[1]])

            dynamicModel.clear()
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            // must NOT snap back to the first chain
            compare(controlUnderTest.selection, [allChainIds()[1]])
        }

        // once the popup content was instantiated it stays alive (latched
        // loader); its internal view must not clobber selection on reset either
        function test_selectionSurvivesModelResetAfterPopupShown() {
            root.enabledChainIds = allChainIds()

            const dynamicModel = createTemporaryQmlObject(
                "import QtQuick; ListModel {}", root)
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            controlUnderTest = createTemporaryObject(componentUnderTest, root,
                {flatNetworks: dynamicModel})
            verify(!!controlUnderTest)

            controlUnderTest.control.popup.open()
            tryCompare(controlUnderTest.control.popup, "opened", true)
            controlUnderTest.control.popup.close()
            tryCompare(controlUnderTest.control.popup, "opened", false)

            compare(controlUnderTest.selection.length, root.enabledChainIds.length)

            dynamicModel.clear()
            for (let i = 0; i < NetworksModel.flatNetworks.count; i++)
                dynamicModel.append({chainId: NetworksModel.flatNetworks.get(i).chainId,
                                     chainName: NetworksModel.flatNetworks.get(i).chainName,
                                     iconUrl: "", layer: 1, isTest: false})

            compare(controlUnderTest.selection.length, root.enabledChainIds.length)
        }

        // SwapInputPanel-style store round trip: store changes must keep
        // flowing into the filter even after the user picked in the popup
        function test_singleSelectionSurvivesPopupInteraction() {
            root.storeChainId = allChainIds()[0]
            controlUnderTest = createTemporaryObject(singleSelectionComponent, root)
            verify(!!controlUnderTest)
            compare(controlUnderTest.selection, [allChainIds()[0]])

            // store-side change before any interaction
            root.storeChainId = allChainIds()[1]
            compare(controlUnderTest.selection, [allChainIds()[1]])

            // user picks a network via the popup view
            controlUnderTest.control.popup.open()
            tryCompare(controlUnderTest.control.popup, "opened", true)
            const thirdName = NetworksModel.flatNetworks.get(2).chainName
            const delegate = findChild(controlUnderTest.control.popup.contentItem,
                                       "networkSelectorDelegate_" + thirdName)
            verify(!!delegate)
            mouseClick(delegate)
            tryCompare(controlUnderTest.control.popup, "opened", false)
            compare(controlUnderTest.selection, [allChainIds()[2]])
            compare(root.storeChainId, allChainIds()[2])

            // store-side change after the interaction must still propagate
            root.storeChainId = allChainIds()[3]
            compare(controlUnderTest.selection, [allChainIds()[3]])
        }

        // wallet-header-style Binding element: same round-trip via popup toggle
        function test_bindingElementSurvivesPopupInteraction() {
            root.enabledChainIds = allChainIds()
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            compare(controlUnderTest.selection.length, root.enabledChainIds.length)

            controlUnderTest.control.popup.open()
            tryCompare(controlUnderTest.control.popup, "opened", true)
            const firstName = NetworksModel.flatNetworks.get(0).chainName
            const delegate = findChild(controlUnderTest.control.popup.contentItem,
                                       "networkSelectorDelegate_" + firstName)
            verify(!!delegate)
            mouseClick(delegate)

            // store reacts to the toggle (RightTabView flow)
            root.enabledChainIds = allChainIds().slice(1)
            compare(controlUnderTest.selection, root.enabledChainIds)

            // and keeps propagating on later store changes
            root.enabledChainIds = allChainIds()
            compare(controlUnderTest.selection, root.enabledChainIds)
        }
    }
}

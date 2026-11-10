import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet

import Models
import utils

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: componentUnderTest
        NetworksView {
            width: root.width
            flatNetworks: NetworksModel.flatNetworks
            areTestNetworksEnabled: false
        }
    }

    Component {
        id: networksModelComponent
        ListModel {}
    }

    SignalSpy {
        id: setNetworkActiveSpy
        signalName: "setNetworkActive"
    }

    TestCase {
        name: "NetworksView"
        when: windowShown

        property var controlUnderTest: null

        function cleanup() {
            controlUnderTest = null
            setNetworkActiveSpy.clear()
        }

        // count mainnets, the first activeCount of them active
        function mainnets(count, activeCount) {
            const model = createTemporaryObject(networksModelComponent, root)
            for (let i = 0; i < count; ++i)
                model.append({ chainId: 1000 + i, chainName: "Chain" + i, iconUrl: "network/ethereum",
                               isTest: false, isActive: i < activeCount, isDeactivatable: i > 0 })
            return model
        }

        function createViewWithSpy(model) {
            createView({ flatNetworks: model })
            setNetworkActiveSpy.target = controlUnderTest
        }

        function test_deactivateNeedsNoConfirmation() {
            createViewWithSpy(mainnets(3, 2))

            delegate("Chain1", 1001).setNetworkActive(false)

            compare(setNetworkActiveSpy.count, 1)
            compare(setNetworkActiveSpy.signalArguments[0][0], 1001)
            compare(setNetworkActiveSpy.signalArguments[0][1], false)
        }

        function test_activateBelowLimit_data() {
            return [
                { tag: "6th network", activeCount: 5 },
                { tag: "20th network", activeCount: 19 },
            ]
        }

        function test_activateBelowLimit(data) {
            createViewWithSpy(mainnets(data.activeCount + 1, data.activeCount))

            const chainId = 1000 + data.activeCount
            delegate("Chain" + data.activeCount, chainId).setNetworkActive(true)

            compare(setNetworkActiveSpy.count, 1)
            compare(setNetworkActiveSpy.signalArguments[0][0], chainId)
            compare(setNetworkActiveSpy.signalArguments[0][1], true)
        }

        function test_activateAtLimitIsRefused() {
            const limit = Constants.maxActiveNetworks
            createViewWithSpy(mainnets(limit + 1, limit))

            delegate("Chain" + limit, 1000 + limit).setNetworkActive(true)

            compare(setNetworkActiveSpy.count, 0)
        }

        function createView(props) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, props || {})
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            return controlUnderTest
        }

        function delegate(chainName, chainId) {
            return findChild(controlUnderTest, "walletNetworkDelegate_%1_%2".arg(chainName).arg(chainId))
        }

        function tabBar() {
            return findChild(controlUnderTest, "testModeViewTabBar")
        }

        function test_mainnetTabListsExpectedNetworks() {
            createView({ areTestNetworksEnabled: false })

            tryCompare(tabBar(), "currentIndex", controlUnderTest.mainnetTabIndex)

            const expected = [
                ["Mainnet", NetworksModel.mainnetChainId],
                ["Optimism", NetworksModel.optChainId],
                ["Arbitrum", NetworksModel.arbChainId],
                ["Base", NetworksModel.baseChainId]
            ]
            for (let i = 0; i < expected.length; ++i) {
                const item = delegate(expected[i][0], expected[i][1])
                verify(!!item)
                compare(item.title, expected[i][0])
            }
            compare(delegate("Hoodi", NetworksModel.hoodiChainId), null)
        }

        function test_testnetEnabledShowsHoodiAndHidesMainnet() {
            createView({ areTestNetworksEnabled: true })

            tryCompare(tabBar(), "currentIndex", controlUnderTest.testnetTabIndex)
            verify(!!delegate("Hoodi", NetworksModel.hoodiChainId))
            compare(delegate("Hoodi", NetworksModel.hoodiChainId).title, "Hoodi")
            compare(delegate("Mainnet", NetworksModel.mainnetChainId), null)
        }

        function test_manualTabSwitchFiltersByIsTest() {
            createView({ areTestNetworksEnabled: false })

            const mainnetTab = findChild(controlUnderTest, "testModeViewMainButton")
            const testnetTab = findChild(controlUnderTest, "testModeViewTestButton")

            mouseClick(testnetTab)
            tryCompare(tabBar(), "currentIndex", controlUnderTest.testnetTabIndex)
            waitForRendering(controlUnderTest)
            verify(!!delegate("Hoodi", NetworksModel.hoodiChainId))
            compare(delegate("Mainnet", NetworksModel.mainnetChainId), null)

            mouseClick(mainnetTab)
            tryCompare(tabBar(), "currentIndex", controlUnderTest.mainnetTabIndex)
            waitForRendering(controlUnderTest)
            verify(!!delegate("Mainnet", NetworksModel.mainnetChainId))
            compare(delegate("Hoodi", NetworksModel.hoodiChainId), null)
        }

        function test_overrideInitialTabIndexIsOneShot() {
            createView({ areTestNetworksEnabled: false })

            controlUnderTest.overrideInitialTabIndex(controlUnderTest.mainnetTabIndex)
            controlUnderTest.areTestNetworksEnabled = true
            tryCompare(tabBar(), "currentIndex", controlUnderTest.mainnetTabIndex)

            controlUnderTest.areTestNetworksEnabled = false
            controlUnderTest.areTestNetworksEnabled = true
            tryCompare(tabBar(), "currentIndex", controlUnderTest.testnetTabIndex)
        }
    }
}

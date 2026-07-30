import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet

import Models

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

    TestCase {
        name: "NetworksView"
        when: windowShown

        property var controlUnderTest: null

        function cleanup() {
            controlUnderTest = null
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

import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Wallet.controls

import utils

Item {
    id: root

    width: 600
    height: 600

    Component {
        id: selectorCmp

        AssetSelector {
            id: selector

            anchors.centerIn: parent

            readonly property var assetsData: [
                {
                    key: "stt_key",
                    communityId: "",
                    name: "Status Test Token",
                    currencyBalance: 42.23,
                    symbol: "STT",
                    logoUri: Constants.tokenIcon("STT"),

                    balances: [
                        {
                            balance: 0.56,
                            iconUrl: "network/ethereum"
                        }
                    ],

                    sectionName: "My assets on Mainnet"
                },
                {
                    key: "eth_key",
                    communityId: "",
                    name: "Ether",
                    currencyBalance: 4276.86,
                    symbol: "ETH",
                    logoUri: Constants.tokenIcon("ETH"),

                    balances: [
                        {
                            balance: 0.12,
                            iconUrl: "network/ethereum"
                        }
                    ],

                    sectionName: "My assets on Mainnet"
                },
                {
                    key: "dai_key",
                    communityId: "",
                    name: "Dai Stablecoin",
                    currencyBalance: 45.92,
                    symbol: "DAI",
                    logoUri: Constants.tokenIcon("DAI"),
                    balances: [],

                    sectionName: "Popular assets"
                }
            ]

            model: ListModel {
                Component.onCompleted: append(selector.assetsData)
            }

            readonly property SignalSpy selectedSpy: SignalSpy {
                target: selector
                signalName: "selected"
            }
        }
    }

    TestCase {
        name: "AssetSelector"
        when: windowShown

        function test_basic() {
            const selector  = createTemporaryObject(selectorCmp, root)
            selector.nonInteractiveKey = "eth_key"
            compare(selector.isSelected, false)
            waitForRendering(selector)

            verify(selector.width > 0)
            verify(selector.height > 0)

            mouseClick(selector)

            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            compare(panel.model, selector.model)
            compare(panel.nonInteractiveKey, selector.nonInteractiveKey)
        }

        function test_basicSelection() {
            const selector = createTemporaryObject(selectorCmp, root)
            const button = selector.contentItem

            compare(selector.isSelected, false)
            compare(button.selected, false)
            waitForRendering(selector)

            // click to open popup
            mouseClick(selector)
            compare(selector.isSelected, false)
            compare(button.selected, false)

            const listView = findChild(selector.Overlay.overlay, "assetsListView")
            verify(listView)

            compare(listView.count, selector.assetsData.length)
            waitForRendering(listView)

            const delegate1 = listView.itemAtIndex(0)
            const delegate2 = listView.itemAtIndex(1)

            verify(delegate1)
            verify(delegate2)

            // click on delegate to select
            mouseClick(delegate2)
            compare(selector.isSelected, true)
            compare(selector.selectedSpy.count, 1)
            compare(selector.selectedSpy.signalArguments[0][0], "eth_key")
            compare(button.selected, true)
            compare(button.name, "ETH")
            compare(button.icon, Constants.tokenIcon("ETH"))

            // popup should be closed, content not accessible
            verify(!findChild(selector.Overlay.overlay, "searchableAssetsPanel"))

            // reopen popup
            mouseClick(selector)
            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            verify(panel)

            compare(panel.highlightedKey, "eth_key")
            compare(panel.nonInteractiveKey, "")
        }

        function test_resetSelection() {
            const selector = createTemporaryObject(selectorCmp, root)
            const button = selector.contentItem

            compare(selector.isSelected, false)
            compare(button.selected, false)
            waitForRendering(selector)

            // click to open popup
            mouseClick(selector)

            const listView = findChild(selector.Overlay.overlay, "assetsListView")
            verify(listView)

            waitForRendering(listView)
            const delegate2 = listView.itemAtIndex(1)

            verify(delegate2)

            // click on delegate to select
            mouseClick(delegate2)
            compare(selector.isSelected, true)

            // reset
            selector.reset()
            compare(selector.isSelected, false)
            compare(button.selected, false)

            // reopen popup
            mouseClick(selector)
            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            verify(panel)

            compare(panel.highlightedKey, "")
            compare(panel.nonInteractiveKey, "")
        }

        function test_customSelection() {
            const selector  = createTemporaryObject(selectorCmp, root)
            const button = selector.contentItem

            compare(selector.isSelected, false)
            waitForRendering(selector)

            const imageUrl = Constants.tokenIcon("DAI")
            selector.setSelection("Custom", imageUrl, "custom_key")

            compare(selector.isSelected, true)
            compare(selector.selectedSpy.count, 0)
            compare(button.selected, true)
            compare(button.name, "Custom")
            compare(button.icon, Constants.tokenIcon("DAI"))
        }

        // An owned aggregate row (single balance chain on "All") badges its
        // balance chain — the selection must land THERE, not on whichever
        // deployment is listed first in the token refs. Replays the mobile
        // report: ETH held only on Optimism (10) resolved to Arbitrum (42161)
        // because 42161 led the refs.
        function test_aggregateRowResolvesToItsBalanceChain() {
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "eth-native", communityId: "", name: "Ether",
                currencyBalance: 10, symbol: "ETH",
                logoUri: Constants.tokenIcon("ETH"),
                balances: [ { chainId: 10, balance: 0.005, iconUrl: "network/optimism" } ],
                tokens: [ { chainId: 42161, key: "42161-0x0" }, { chainId: 10, key: "10-0x0" },
                          { chainId: 1, key: "1-0x0" }, { chainId: 8453, key: "8453-0x0" } ],
                sectionName: "Your assets"
            })

            const selector = createTemporaryObject(selectorCmp, root)
            selector.model = data
            // the receive side holds this token on chain 1 — excluded, but
            // irrelevant to the balance-chain pick
            selector.nonInteractiveKey = "eth-native"
            selector.nonInteractiveChainId = 1
            waitForRendering(selector)

            mouseClick(selector)
            const listView = findChild(selector.Overlay.overlay, "assetsListView")
            verify(listView)
            waitForRendering(listView)

            const eth = listView.itemAtIndex(0)
            verify(eth)
            verify(eth.rowAt(0).enabled)
            eth.selectFirst()

            compare(selector.selectedSpy.count, 1)
            compare(selector.selectedSpy.signalArguments[0][0], "eth-native")
            compare(selector.selectedSpy.signalArguments[0][1], 10) // the balance chain, not refs[0]
        }

        // Clicking the other panel's token from an unscoped list must resolve
        // to another of its chains — never the blocked chain-address pair.
        function test_selectionSkipsTheNonInteractiveChain() {
            // fresh model: the fixture's has no `tokens` role, and a ListModel's
            // role set is frozen by its first append
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "usdc_key", communityId: "", name: "USD Coin",
                currencyBalance: 0, symbol: "USDC",
                logoUri: Constants.tokenIcon("USDC"),
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xaaa" }, { chainId: 10, key: "10-0xbbb" } ],
                sectionName: "Popular assets"
            })

            const selector = createTemporaryObject(selectorCmp, root)
            selector.model = data
            selector.nonInteractiveKey = "usdc_key"
            selector.nonInteractiveChainId = 1
            waitForRendering(selector)

            mouseClick(selector)
            const listView = findChild(selector.Overlay.overlay, "assetsListView")
            verify(listView)
            waitForRendering(listView)

            const usdc = listView.itemAtIndex(0)
            verify(usdc)
            verify(usdc.rowAt(0).enabled)

            usdc.selectFirst()
            compare(selector.selectedSpy.count, 1)
            compare(selector.selectedSpy.signalArguments[0][0], "usdc_key")
            compare(selector.selectedSpy.signalArguments[0][1], 10)
        }

        // Even if a selection slips past the row's disabled state (keyboard
        // paths, stale model), the selector must not commit the blocked pair —
        // nor an unresolved chain that a later adoption could land on it.
        function test_finalGuardBlocksTheNonInteractivePair() {
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "only1_key", communityId: "", name: "OnlyOne",
                currencyBalance: 0, symbol: "ONE", logoUri: "",
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xccc" } ],
                sectionName: "Popular assets"
            })

            const selector = createTemporaryObject(selectorCmp, root)
            selector.model = data
            selector.nonInteractiveKey = "only1_key"
            selector.nonInteractiveChainId = 1
            waitForRendering(selector)

            mouseClick(selector) // open the dropdown
            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            verify(panel)

            // bypass the delegate and emit straight from the panel: the only
            // deployment is the blocked chain, so nothing may be committed
            panel.selected("only1_key", -1)
            compare(selector.selectedSpy.count, 0)
            compare(selector.isSelected, false)
            verify(!!findChild(selector.Overlay.overlay, "searchableAssetsPanel"),
                   "the dropdown stays open instead of closing on a refused pick")

            panel.selected("only1_key", 1) // the blocked pair, explicitly
            compare(selector.selectedSpy.count, 0)
            compare(selector.isSelected, false)
        }

        // With the -1 wildcard the token is excluded on every chain: even a
        // selection arriving with a CONCRETE chain must be refused.
        function test_finalGuardBlocksWildcardExclusionOnAnyChain() {
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "usdc_key", communityId: "", name: "USD Coin",
                currencyBalance: 0, symbol: "USDC",
                logoUri: Constants.tokenIcon("USDC"),
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xaaa" }, { chainId: 10, key: "10-0xbbb" } ],
                sectionName: "Popular assets"
            })

            const selector = createTemporaryObject(selectorCmp, root)
            selector.model = data
            selector.nonInteractiveKey = "usdc_key"
            selector.nonInteractiveChainId = -1
            waitForRendering(selector)

            mouseClick(selector) // open the dropdown
            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            verify(panel)

            panel.selected("usdc_key", 1)  // concrete chain under the wildcard
            compare(selector.selectedSpy.count, 0)
            compare(selector.isSelected, false)

            panel.selected("usdc_key", -1) // unresolved chain
            compare(selector.selectedSpy.count, 0)
            compare(selector.isSelected, false)
        }

        function test_searchNotPersistent() {
            const selector = createTemporaryObject(selectorCmp, root)
            const button = selector.contentItem

            compare(selector.isSelected, false)
            compare(button.selected, false)
            waitForRendering(selector)

            // click to open popup
            mouseClick(selector)

            const panel = findChild(selector.Overlay.overlay, "searchableAssetsPanel")
            verify(panel)

            const searchBox = findChild(panel, "searchBox")
            verify(searchBox)

            compare(searchBox.text, "")
            searchBox.text = "seach string"
            keyClick(Qt.Key_Escape)

            // click to re-open popup
            mouseClick(selector)
            {
                const searchBox = findChild(panel, "searchBox")
                verify(searchBox)
                compare(searchBox.text, "")
            }
        }
    }
}

import QtQuick
import QtTest

import AppLayouts.Wallet.panels

import StatusQ.Core.Theme

import Storybook

import utils
import SortFilterProxyModel
import StatusQ.Core.Utils as SQUtils

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: panelCmp

        Item {
            id: container

            property string searchKeyword: ""
            property alias panel: panelInstance

            // set to enable the in-panel chain chip row (and with it the per-chain
            // row split when no chain is selected)
            property var networksModel: null

            property ListModel sourceModel: ListModel {
                Component.onCompleted: append(panelInstance.assetsData)
            }

            SearchableAssetsPanel {
                id: panelInstance

                model: SortFilterProxyModel {
                    sourceModel: container.sourceModel

                    filters: [
                        AnyOf {
                            SQUtils.SearchFilter {
                                roleName: "name"
                                searchPhrase: container.searchKeyword
                            }
                            SQUtils.SearchFilter {
                                roleName: "symbol"
                                searchPhrase: container.searchKeyword
                            }
                        }
                    ]
                }

                flatNetworksModel: container.networksModel

                onSearch: function(keyword) {
                    container.searchKeyword = keyword.trim()
                }

                readonly property var assetsData: [
                {
                    key: "stt_key",
                    communityId: "",
                    name: "Status Test Token",
                    currencyBalance: 42.23,
                    symbol: "STT",
                    logoUri: Constants.tokenIcon("STT"),
                    cryptoPrice: 100,
                    currentBalance: 0.9,
                    balances: [
                        {
                            chainId: 1,
                            balance: 0.56,
                            iconUrl: "network/ethereum"
                        },
                        {
                            chainId: 42161,
                            balance: 0.22,
                            iconUrl: "network/arbitrum"
                        },
                        {
                            chainId: 10,
                            balance: 0.12,
                            iconUrl: "network/optimism"
                        }
                    ],

                    sectionName: ""
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
                },
                {
                    key: "zrx_key",
                    communityId: "",
                    name: "0x",
                    currencyBalance: 41.22,
                    symbol: "ZRX",
                    logoUri: Constants.tokenIcon("ZRX"),
                    balances: [],

                    sectionName: "Popular assets"
                }
                ]

                readonly property SignalSpy selectedSpy: SignalSpy {
                    target: panelInstance
                    signalName: "selected"
                }
            }
        }
    }

    TestCase {
        name: "SearchableAssetsPanel"
        when: windowShown

        function test_sections() {
            const control = createTemporaryObject(panelCmp, root)

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            compare(listView.count, 3)

            const delegate1 = listView.itemAtIndex(0)
            const delegate2 = listView.itemAtIndex(1)
            const delegate3 = listView.itemAtIndex(2)

            verify(delegate1)
            verify(delegate2)
            verify(delegate3)

            compare(delegate1.ListView.section, "")
            compare(delegate2.ListView.section, "Popular assets")
            compare(delegate3.ListView.section, "Popular assets")

            const sectionDelegate = TestUtils.findTextItem(listView, "Popular assets")
            verify(sectionDelegate)
        }

        function test_withNoSectionsModel() {
            const model = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            const control = createTemporaryObject(panelCmp, root)

            model.append(control.panel.assetsData.map(
                e => ({
                        key: e.key,
                        communityId: e.communityId,
                        name: e.name,
                        currencyBalance: e.currencyBalance,
                        symbol: e.symbol,
                        logoUri: e.logoUri,
                        balances: e.balances,
                        sectionName: ""
                    })
                )
            )

            control.sourceModel = model

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)
            compare(listView.count, 3)

            const delegate1 = listView.itemAtIndex(0)
            const delegate2 = listView.itemAtIndex(1)
            const delegate3 = listView.itemAtIndex(2)

            verify(delegate1)
            verify(delegate2)
            verify(delegate3)

            compare(delegate1.ListView.section, "")
            compare(delegate2.ListView.section, "")
            compare(delegate3.ListView.section, "")
        }

        function test_search() {
            const control = createTemporaryObject(panelCmp, root)

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            const searchBox = findChild(control, "searchBox")

            {
                control.searchKeyword = "Status"
                searchBox.text = "Status"
                waitForRendering(listView)

                compare(listView.count, 1)
                const delegate1 = listView.itemAtIndex(0)
                verify(delegate1)
                compare(delegate1.rowAt(0).name, "Status Test Token")
                verify(delegate1.rowAt(0).isAutoHovered)
                compare(delegate1.rowAt(0).background.color, Theme.palette.baseColor2)
            }
            {
                control.searchKeyword = "zrx"
                searchBox.text = "zrx"
                waitForRendering(listView)

                compare(listView.count, 1)
                const delegate1 = listView.itemAtIndex(0)
                verify(delegate1)
                compare(delegate1.rowAt(0).name, "0x")
                verify(delegate1.rowAt(0).isAutoHovered)
                compare(delegate1.rowAt(0).background.color, Theme.palette.baseColor2)
            }
            {
                control.searchKeyword = ""
                searchBox.text = ""
                waitForRendering(listView)

                compare(searchBox.text, "")
                compare(listView.count, 3)
            }
        }

        // A search with no matches shows the placeholder where the list would
        // be — below the search box, never above it.
        function test_emptySearchResultShowsPlaceholderInListArea() {
            const control = createTemporaryObject(panelCmp, root)

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            const searchBox = findChild(control, "searchBox")
            const placeholder = findChild(control, "emptyListPlaceholder")
            verify(!!placeholder)
            verify(!placeholder.visible, "placeholder hidden while the list has rows")

            control.searchKeyword = "no-such-token"
            searchBox.text = "no-such-token"
            waitForRendering(listView)

            compare(listView.count, 0)
            verify(placeholder.visible, "placeholder replaces the empty list")
            verify(searchBox.visible, "the search box stays usable above it")
            verify(placeholder.mapToItem(control, 0, 0).y >
                   searchBox.mapToItem(control, 0, 0).y,
                   "the placeholder sits below the search box, not on top of the panel")

            control.searchKeyword = ""
            searchBox.text = ""
            waitForRendering(listView)
            verify(!placeholder.visible)
        }

        function test_highlightedKey() {
            const control = createTemporaryObject(panelCmp, root)
            control.panel.highlightedKey = "dai_key"

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            compare(listView.count, 3)

            const delegate1 = listView.itemAtIndex(0)
            const delegate2 = listView.itemAtIndex(1)
            const delegate3 = listView.itemAtIndex(2)

            verify(delegate1)
            verify(delegate2)
            verify(delegate3)

            compare(delegate1.rowAt(0).highlighted, false)
            compare(delegate2.rowAt(0).highlighted, true)
            compare(delegate3.rowAt(0).highlighted, false)
        }

        function test_nonInteractiveKey() {
            const control = createTemporaryObject(panelCmp, root)
            control.panel.nonInteractiveKey = "dai_key"

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            compare(listView.count, 3)

            const delegate1 = listView.itemAtIndex(0)
            const delegate2 = listView.itemAtIndex(1)
            const delegate3 = listView.itemAtIndex(2)

            verify(delegate1)
            verify(delegate2)
            verify(delegate3)

            compare(delegate1.rowAt(0).enabled, true)
            compare(delegate2.rowAt(0).enabled, false)
            compare(delegate3.rowAt(0).enabled, true)

            mouseClick(delegate1)
            compare(control.panel.selectedSpy.count, 1)

            mouseClick(delegate2)
            compare(control.panel.selectedSpy.count, 1)

            mouseClick(delegate3)
            compare(control.panel.selectedSpy.count, 2)
        }

        readonly property var networksData: [
            { chainId: 1, chainName: "Ethereum", iconUrl: "network/ethereum" },
            { chainId: 10, chainName: "Optimism", iconUrl: "network/optimism" },
            { chainId: 42161, chainName: "Arbitrum", iconUrl: "network/arbitrum" }
        ]

        function test_perChainRowsWhenNoChainFilter() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            verify(control.panel.expandPerChain)

            // STT sits on 3 chains -> 3 rows; the popular tokens have no balance
            const stt = listView.itemAtIndex(0)
            verify(stt)
            compare(stt.rowCount, 3)
            compare(listView.itemAtIndex(1).rowCount, 1)
            compare(listView.itemAtIndex(2).rowCount, 1)

            // biggest sub-balance first, as the model orders the chips
            compare(stt.rowAt(0).chainId, 1)
            compare(stt.rowAt(1).chainId, 42161)
            compare(stt.rowAt(2).chainId, 10)

            // each row shows only its own chain's balance, not the sum
            compare(stt.rowAt(0).currentBalance, 0.56)
            compare(stt.rowAt(1).currentBalance, 0.22)
            compare(stt.rowAt(2).currentBalance, 0.12)

            // ...and selecting one names that chain
            mouseClick(stt.rowAt(1))
            compare(control.panel.selectedSpy.count, 1)
            compare(control.panel.selectedSpy.signalArguments[0][0], "stt_key")
            compare(control.panel.selectedSpy.signalArguments[0][1], 42161)
        }

        function test_nonInteractiveKeyOnlyExcludesItsOwnChain() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.panel.nonInteractiveKey = "stt_key"
            control.panel.nonInteractiveChainId = 1

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            // STT sits on 1, 42161 and 10; only the chain the caller excluded is a
            // same-chain duplicate — the others are bridge destinations
            const stt = listView.itemAtIndex(0)
            verify(stt)
            compare(stt.rowCount, 3)
            compare(stt.rowAt(0).chainId, 1)
            compare(stt.rowAt(0).enabled, false)
            compare(stt.rowAt(1).enabled, true)
            compare(stt.rowAt(2).enabled, true)

            mouseClick(stt.rowAt(1))
            compare(control.panel.selectedSpy.count, 1)
            compare(control.panel.selectedSpy.signalArguments[0][1], 42161)
        }

        function test_nonInteractiveKeyFollowsTheChainFilter() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.panel.nonInteractiveKey = "stt_key"
            control.panel.nonInteractiveChainId = 1

            const listView = findChild(control, "assetsListView")

            // scoped to the excluded chain: the same (token, chain) pair
            control.panel.selectedChainId = 1
            waitForRendering(listView)
            const sttExcluded = listView.itemAtIndex(0)
            verify(sttExcluded)
            compare(sttExcluded.rowCount, 1)
            compare(sttExcluded.rowAt(0).enabled, false)

            // scoped to another chain: a legitimate bridge destination
            control.panel.selectedChainId = 10
            waitForRendering(listView)
            const sttBridge = listView.itemAtIndex(0)
            verify(sttBridge)
            compare(sttBridge.rowCount, 1)
            compare(sttBridge.rowAt(0).enabled, true)
        }

        // On "All" (no chain filter) the other side's token collapses into one
        // aggregate row; it must stay selectable when the token also lives on
        // other chains — only a token locked to the excluded chain (or excluded
        // everywhere via -1) is blocked.
        function test_nonInteractiveAggregateRowSelectableOnAnotherChain() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            // fresh source: the fixture's model has no `tokens` role, and a
            // ListModel's role set is frozen by its first append
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "usdc_key", communityId: "", name: "USD Coin",
                currencyBalance: 0, symbol: "USDC", logoUri: Constants.tokenIcon("USDC"),
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xaaa" }, { chainId: 10, key: "10-0xbbb" } ],
                sectionName: "Popular assets"
            })
            data.append({
                key: "only1_key", communityId: "", name: "OnlyOne",
                currencyBalance: 0, symbol: "ONE", logoUri: "",
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xccc" } ],
                sectionName: "Popular assets"
            })

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.sourceModel = data
            control.panel.nonInteractiveKey = "usdc_key"
            control.panel.nonInteractiveChainId = 1

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)
            compare(listView.count, 2)

            const usdc = listView.itemAtIndex(0)
            verify(usdc)
            compare(usdc.rowCount, 1)          // no balances -> one aggregate row
            compare(usdc.rowAt(0).enabled, true)   // chain 10 is a legal pick

            control.panel.nonInteractiveKey = "only1_key"
            const only1 = listView.itemAtIndex(1)
            verify(only1)
            compare(only1.rowAt(0).enabled, false) // no other chain to pick
            compare(usdc.rowAt(0).enabled, true)   // no longer the excluded key

            // -1 still excludes the holding on every chain
            control.panel.nonInteractiveKey = "usdc_key"
            control.panel.nonInteractiveChainId = -1
            compare(usdc.rowAt(0).enabled, false)
        }

        // nonInteractiveChainId === -1 excludes the holding on EVERY chain —
        // the per-chain split rows of a multi-chain holding included.
        function test_wildcardExclusionDisablesEveryPerChainRow() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.panel.nonInteractiveKey = "stt_key"
            control.panel.nonInteractiveChainId = -1

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            // STT sits on 3 chains -> 3 concrete rows, all of them blocked
            const stt = listView.itemAtIndex(0)
            verify(stt)
            compare(stt.rowCount, 3)
            for (let i = 0; i < stt.rowCount; i++)
                compare(stt.rowAt(i).enabled, false)

            mouseClick(stt.rowAt(1))
            compare(control.panel.selectedSpy.count, 0)

            // other holdings stay unaffected
            compare(listView.itemAtIndex(1).rowAt(0).enabled, true)
        }

        // Enter must be as strict as the mouse: a result available only on the
        // excluded chain is not selectable by keyboard either.
        function test_keyboardSelectionRespectsDisabledRows() {
            const data = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            data.append({
                key: "only1_key", communityId: "", name: "OnlyOne",
                currencyBalance: 0, symbol: "ONE", logoUri: "",
                balances: [],
                tokens: [ { chainId: 1, key: "1-0xccc" } ],
                sectionName: "Popular assets"
            })

            const control = createTemporaryObject(panelCmp, root)
            control.sourceModel = data
            control.panel.nonInteractiveKey = "only1_key"
            control.panel.nonInteractiveChainId = 1

            const listView = findChild(control, "assetsListView")
            const searchBox = findChild(control, "searchBox")
            control.searchKeyword = "one"
            searchBox.text = "one"
            waitForRendering(listView)
            compare(listView.count, 1)
            verify(!listView.itemAtIndex(0).rowAt(0).enabled)

            // the Enter/Return handlers funnel through selectFirst()
            listView.itemAtIndex(0).selectFirst()
            compare(control.panel.selectedSpy.count, 0)

            // once unblocked, the same path selects it
            control.panel.nonInteractiveKey = ""
            listView.itemAtIndex(0).selectFirst()
            compare(control.panel.selectedSpy.count, 1)
        }

        function test_singleRowWhenChainFilterSet() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.panel.selectedChainId = 10

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            verify(!control.panel.expandPerChain)
            compare(listView.itemAtIndex(0).rowCount, 1)

            // aggregate row: no chain pinned, so the caller resolves it
            mouseClick(listView.itemAtIndex(0).rowAt(0))
            compare(control.panel.selectedSpy.count, 1)
            compare(control.panel.selectedSpy.signalArguments[0][1], -1)
        }

        function test_highlightedChainIdPicksTheRow() {
            const networks = createTemporaryQmlObject("import QtQml.Models; ListModel {}", root)
            networks.append(networksData)

            const control = createTemporaryObject(panelCmp, root, { networksModel: networks })
            control.panel.highlightedKey = "stt_key"
            control.panel.highlightedChainId = 10

            const listView = findChild(control, "assetsListView")
            waitForRendering(listView)

            const stt = listView.itemAtIndex(0)
            compare(stt.rowAt(0).highlighted, false)
            compare(stt.rowAt(1).highlighted, false)
            compare(stt.rowAt(2).highlighted, true)
        }
    }
}

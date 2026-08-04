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

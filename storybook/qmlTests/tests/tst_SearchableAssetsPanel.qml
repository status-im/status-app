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

                onSearch: function(keyword) {
                    container.searchKeyword = keyword.trim()
                }

                readonly property var assetsData: [
                {
                    key: "stt_key",
                    communityId: "",
                    name: "Status Test Token",
                    currencyBalanceAsString: "42,23 USD",
                    symbol: "STT",
                    logoUri: Constants.tokenIcon("STT"),
                    balances: [
                        {
                            balanceAsString: "0,56",
                            iconUrl: "network/ethereum"
                        },
                        {
                            balanceAsString: "0,22",
                            iconUrl: "network/arbitrum"
                        },
                        {
                            balanceAsString: "0,12",
                            iconUrl: "network/optimism"
                        }
                    ],

                    sectionName: ""
                },
                {
                    key: "dai_key",
                    communityId: "",
                    name: "Dai Stablecoin",
                    currencyBalanceAsString: "45,92 USD",
                    symbol: "DAI",
                    logoUri: Constants.tokenIcon("DAI"),
                    balances: [],

                    sectionName: "Popular assets"
                },
                {
                    key: "zrx_key",
                    communityId: "",
                    name: "0x",
                    currencyBalanceAsString: "41,22 USD",
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
                        currencyBalanceAsString: e.currencyBalanceAsString,
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
                compare(delegate1.name, "Status Test Token")
                verify(delegate1.isAutoHovered)
                compare(delegate1.background.color, Theme.palette.baseColor2)
            }
            {
                control.searchKeyword = "zrx"
                searchBox.text = "zrx"
                waitForRendering(listView)

                compare(listView.count, 1)
                const delegate1 = listView.itemAtIndex(0)
                verify(delegate1)
                compare(delegate1.name, "0x")
                verify(delegate1.isAutoHovered)
                compare(delegate1.background.color, Theme.palette.baseColor2)
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

            compare(delegate1.highlighted, false)
            compare(delegate2.highlighted, true)
            compare(delegate3.highlighted, false)
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

            compare(delegate1.enabled, true)
            compare(delegate2.enabled, false)
            compare(delegate3.enabled, true)

            mouseClick(delegate1)
            compare(control.panel.selectedSpy.count, 1)

            mouseClick(delegate2)
            compare(control.panel.selectedSpy.count, 1)

            mouseClick(delegate3)
            compare(control.panel.selectedSpy.count, 2)
        }
    }
}

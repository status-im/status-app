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
                    currencyBalanceAsString: "42,23 USD",
                    symbol: "STT",
                    logoUri: Constants.tokenIcon("STT"),

                    balances: [
                        {
                            balanceAsString: "0,56",
                            iconUrl: "network/ethereum"
                        }
                    ],

                    sectionName: "My assets on Mainnet"
                },
                {
                    key: "eth_key",
                    communityId: "",
                    name: "Ether",
                    currencyBalanceAsString: "4 276,86 USD",
                    symbol: "ETH",
                    logoUri: Constants.tokenIcon("ETH"),

                    balances: [
                        {
                            balanceAsString: "0,12",
                            iconUrl: "network/ethereum"
                        }
                    ],

                    sectionName: "My assets on Mainnet"
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

import QtQuick
import QtTest

import AppLayouts.Wallet.panels
import utils

Item {
    id: root

    width: 600
    height: 800

    ListModel {
        id: emptyModel
    }

    ListModel {
        id: collectiblesModel

        Component.onCompleted: append([{
            groupName: "ERC-721 Faucet",
            type: "other",
            thumbnailUrl: "",
            imageUrl: "",
            iconUrl: "",
            subitems: [
                {
                    key: "erc721",
                    name: "Faucet token",
                    balance: 1,
                    tokenType: 2,
                    icon: "",
                    iconUrl: ""
                },
                {
                    key: "erc1155",
                    name: "Edition",
                    balance: 5,
                    tokenType: 3,
                    icon: "",
                    iconUrl: ""
                }
            ]
        }])
    }

    Component {
        id: emptyPanelComponent

        SearchableCollectiblesPanel {
            width: 360
            height: 200
            model: emptyModel
        }
    }

    Component {
        id: panelComponent

        SearchableCollectiblesPanel {
            id: panel

            width: 360
            height: 480
            model: collectiblesModel

            property alias selectedSpy: selectedSpy

            SignalSpy {
                id: selectedSpy
                target: panel
                signalName: "collectibleSelected"
            }
        }
    }

    function findVisibleText(item, expected) {
        if (!item)
            return null
        if (item.text === expected && item.visible)
            return item
        if (!item.children)
            return null
        for (let i = 0; i < item.children.length; ++i) {
            const found = findVisibleText(item.children[i], expected)
            if (found)
                return found
        }
        return null
    }

    TestCase {
        name: "SearchableCollectiblesPanel"
        when: windowShown

        function test_empty_hidesSearch() {
            const panel = createTemporaryObject(emptyPanelComponent, root)
            waitForRendering(panel)

            const search = findChild(panel, "collectiblesSearchBox")
            verify(!!search)
            compare(search.visible, false)
            verify(!!findVisibleText(panel, "Your collectibles will appear here"))
        }

        function test_searchOpensCollectionAndSelectsToken() {
            const panel = createTemporaryObject(panelComponent, root)
            waitForRendering(panel)

            const search = findChild(panel, "collectiblesSearchBox")
            verify(!!search)
            verify(search.visible)

            search.text = "ERC-721 Faucet"
            const collection = findChild(panel, "tokenSelectorCollectibleDelegate_ERC-721 Faucet")
            verify(!!collection)
            tryVerify(() => collection.visible)
            compare(collection.goDeeperIconVisible, true)

            mouseClick(collection)

            let erc721 = null
            let erc1155 = null
            tryVerify(function() {
                erc721 = findChild(panel, "tokenSelectorCollectibleDelegate_Faucet token")
                erc1155 = findChild(panel, "tokenSelectorCollectibleDelegate_Edition")
                return !!erc721 && erc721.visible && !!erc1155 && erc1155.visible
            })
            compare(erc721.balance, "")
            compare(erc721.tokenType, 2)
            compare(erc1155.balance, "5")
            compare(erc1155.tokenType, 3)

            mouseClick(erc721)
            compare(panel.selectedSpy.count, 1)
            compare(panel.selectedSpy.signalArguments[0][0], "erc721")

            mouseClick(erc1155)
            compare(panel.selectedSpy.count, 2)
            compare(panel.selectedSpy.signalArguments[1][0], "erc1155")
        }
    }
}

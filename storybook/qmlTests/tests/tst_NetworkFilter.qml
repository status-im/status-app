import QtQuick
import QtTest

import AppLayouts.Wallet.controls

Item {
    id: root
    width: 600
    height: 600

    Component {
        id: networksModelComponent
        ListModel {}
    }

    Component {
        id: componentUnderTest
        NetworkFilter {
            multiSelection: true
        }
    }

    TestCase {
        name: "NetworkFilter"
        when: windowShown

        function networks(count) {
            const model = createTemporaryObject(networksModelComponent, root)
            for (let i = 0; i < count; ++i)
                model.append({ chainId: 1000 + i, chainName: "Chain" + i, iconUrl: "network/ethereum",
                               isTest: false, layer: 2 })
            return model
        }

        function createFilter(networkCount, selectedCount) {
            const selection = []
            for (let i = 0; i < selectedCount; ++i)
                selection.push(1000 + i)
            const filter = createTemporaryObject(componentUnderTest, root,
                                                 { flatNetworks: networks(networkCount), selection })
            verify(!!filter)
            waitForRendering(filter)
            return filter
        }

        function visibleIcons(filter) {
            const row = findChild(filter, "networkIcons")
            verify(!!row)
            return row.children.filter(child => child.visible && child.image !== undefined).length
        }

        function test_iconsWhenFewNetworksSelected() {
            const filter = createFilter(15, 3)

            compare(visibleIcons(filter), 3)
            compare(findChild(filter, "contentItemText").text, "")
        }

        function test_iconsCappedWhenManyNetworksSelected() {
            const filter = createFilter(15, 15)

            compare(visibleIcons(filter), 5)
            compare(findChild(filter, "contentItemText").text, "+10")
        }
    }
}

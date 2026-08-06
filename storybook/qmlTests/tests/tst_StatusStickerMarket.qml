import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 500
    height: 700

    ListModel {
        id: emptyStickersModel
    }

    ListModel {
        id: packsModel
    }

    Component {
        id: componentUnderTest
        Item {
            id: harness
            width: 460
            height: 640

            property alias market: stickerMarket
            property alias previousView: previousViewItem

            Item {
                id: previousViewItem
                objectName: "stickersPreviousView"
                anchors.fill: parent
                visible: false
            }

            StatusStickerMarket {
                id: stickerMarket
                anchors.fill: parent
                visible: true
                stickerPacks: packsModel
                marketVisible: true
                isWalletEnabled: false
                onBackClicked: {
                    // Mirrors StatusStickersPopup: leave market, restore previous stickers view
                    stickerMarket.visible = false
                    previousViewItem.visible = true
                }
            }
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusStickerMarket"
        when: windowShown

        property var harnessUnderTest: null
        property StatusStickerMarket controlUnderTest: null

        function initTestCase() {
            packsModel.clear()
            packsModel.append({
                packId: "pack-free",
                name: "Free Pack",
                author: "status",
                price: 0,
                installed: false,
                bought: false,
                pending: false,
                preview: "",
                thumbnail: "",
                stickers: emptyStickersModel
            })
            packsModel.append({
                packId: "pack-paid",
                name: "Paid Pack",
                author: "status",
                price: 50,
                installed: false,
                bought: false,
                pending: false,
                preview: "",
                thumbnail: "",
                stickers: emptyStickersModel
            })
        }

        function init() {
            harnessUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!harnessUnderTest)
            controlUnderTest = harnessUnderTest.market
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (harnessUnderTest)
                harnessUnderTest.destroy()
            harnessUnderTest = null
            controlUnderTest = null
        }

        function test_wallet_disabled_shows_only_free_pack() {
            controlUnderTest.isWalletEnabled = false
            waitForRendering(controlUnderTest)

            const grid = findChild(controlUnderTest, "stickerMarketStatusGridView")
            verify(!!grid)
            tryCompare(grid, "count", 1)
        }

        function test_wallet_enabled_shows_both_packs() {
            controlUnderTest.isWalletEnabled = true
            waitForRendering(controlUnderTest)

            const grid = findChild(controlUnderTest, "stickerMarketStatusGridView")
            verify(!!grid)
            tryCompare(grid, "count", 2)
        }

        function test_back_returns_to_previous_view() {
            signalSpy.setup(controlUnderTest, "backClicked")

            verify(controlUnderTest.visible)
            verify(!harnessUnderTest.previousView.visible)

            const backButton = findChild(controlUnderTest, "stickerMarketBackButton")
            verify(!!backButton)
            mouseClick(backButton)

            compare(signalSpy.count, 1)
            verify(!controlUnderTest.visible)
            verify(harnessUnderTest.previousView.visible)
        }
    }
}

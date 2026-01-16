import QtQuick
import QtTest

import AppLayouts.Wallet.views

import Storybook

import StatusQ.Core.Theme

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: delegateCmp

        TokenSelectorAssetDelegate {
            id: delegate

            name: "Ether"
            symbol: "ETH"
            currencyBalanceAsString: "42.02 USD"
            iconSource: ""
            isAutoHovered: false
            width: 250

            readonly property SignalSpy clickSpy: SignalSpy {
                target: delegate
                signalName: "clicked"
            }
        }
    }

    ListModel {
        id: balancesModel

        ListElement {
            balanceAsString: "1234.50"
            iconUrl: "network/ethereum"
        }
        ListElement {
            balanceAsString: "33.52"
            iconUrl: "network/arbitrum"
        }
    }

    TestCase {
        name: "TokenSelectorAssetDelegate"
        when: windowShown

        function test_elision() {
            const control = createTemporaryObject(delegateCmp, root)

            const nameText = TestUtils.findTextItem(control, "Ether")
            const symbolText = TestUtils.findTextItem(control, "ETH")
            const balanceText = TestUtils.findTextItem(control, "42.02 USD")

            verify(nameText)
            verify(symbolText)
            verify(balanceText)

            verify(nameText.visible)
            verify(symbolText.visible)
            verify(balanceText.visible)

            waitForRendering(control)

            verify(nameText.width > 0)
            verify(symbolText.width > 0)
            verify(balanceText.width > 0)

            verify(!nameText.truncated)
            verify(!symbolText.truncated)
            verify(!balanceText.truncated)

            control.name = "Ether ".repeat(10)

            verify(nameText.truncated)
            verify(!symbolText.truncated)
            verify(!balanceText.truncated)
        }

        function test_noBalances() {
            const control = createTemporaryObject(delegateCmp, root)

            const list = findChild(control, "balancesListView")
            compare(list.visible, false)
            compare(list.count, 0)
            compare(list.interactive, true)

            compare(control.opacity, 1)
            control.enabled = false
            verify(control.opacity < 1)

            mouseClick(control)
            compare(control.clickSpy.count, 0)

            control.enabled = true

            mouseClick(control)
            compare(control.clickSpy.count, 1)
        }

        function test_withBalances() {
            const control = createTemporaryObject(delegateCmp, root,
                                                  { balancesModel })

            const list = findChild(control, "balancesListView")
            waitForRendering(list)

            compare(list.visible, true)
            compare(list.count, 2)
            compare(list.interactive, true)

            mouseClick(control)
            compare(control.clickSpy.count, 1)

            mouseClick(list)
            compare(control.clickSpy.count, 2)

            control.balancesListInteractive = false
            compare(list.interactive, false)

            const subBalanceText1 = TestUtils.findTextItem(control, "1234.50")
            const subBalanceText2 = TestUtils.findTextItem(control, "33.52")

            verify(subBalanceText1)
            verify(subBalanceText2)

            verify(subBalanceText1.visible)
            verify(subBalanceText2.visible)
        }


        function test_hovered_highlighted_states() {
            const control = createTemporaryObject(delegateCmp, root,
                                                  { balancesModel })

            control.highlighted = true
            compare(control.background.color, Theme.palette.statusListItem.highlightColor)

            mouseMove(control, control.width/2, control.height/2)
            compare(control.hovered, true)
            compare(control.background.color, Theme.palette.baseColor2)

            control.highlighted = false
            mouseMove(control, control.width/2, control.height/2)
            compare(control.hovered, true)
            compare(control.background.color, Theme.palette.baseColor2)

            // test isAutoHovered behaviour
            control.isAutoHovered = true
            compare(control.background.color, Theme.palette.baseColor2)
        }
    }
}

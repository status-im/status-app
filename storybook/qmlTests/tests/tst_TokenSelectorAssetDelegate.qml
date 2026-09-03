import QtQuick
import QtTest

import AppLayouts.Wallet.views

import Storybook

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

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

    readonly property string tokenAddress: "0x1234567890abcdef1234567890abcdef12345678"

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

            compare(control.networkIconUrl, "")
            compare(control.tokenAddress, "")
            compare(control.hasNetworkBadge, false)
            compare(control.hasAddressChip, false)

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
            const control = createTemporaryObject(delegateCmp, root, {
                networkIconUrl: "network/ethereum",
                tokenAddress: root.tokenAddress,
                cryptoBalanceStr: "1234.50"
            })

            waitForRendering(control)

            compare(control.effectiveNetworkIcon, "network/ethereum")
            compare(control.hasNetworkBadge, true)
            compare(control.hasAddressChip, true)

            const cryptoText = TestUtils.findTextItem(control, "1234.50")
            const fiatText = TestUtils.findTextItem(control, "42.02 USD")

            verify(cryptoText)
            verify(fiatText)

            verify(cryptoText.visible)
            verify(fiatText.visible)

            const chipText = TestUtils.findTextItem(
                    control, SQUtils.Utils.elideAndFormatWalletAddress(root.tokenAddress))

            verify(chipText)
            verify(chipText.visible)

            // a click beside the chip selects the asset
            mouseClick(control, 10, 10)
            compare(control.clickSpy.count, 1)

            // a click on the chip is consumed by it: it requests the contract
            // link and must not select the asset
            const chipSpy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            chipSpy.target = control
            chipSpy.signalName = "contractAddressClicked"

            const chipArea = findChild(control, "addressChipMouseArea")
            verify(chipArea)
            waitForRendering(control)
            const chipCenter = chipArea.mapToItem(control, chipArea.width / 2, chipArea.height / 2)
            mouseClick(control, chipCenter.x, chipCenter.y)

            tryCompare(chipSpy, "count", 1)
            compare(control.clickSpy.count, 1)
        }

        function test_networkBadgeFallback() {
            const control = createTemporaryObject(delegateCmp, root, {
                networkIconUrl: "",
                defaultNetworkIcon: "network/arbitrum"
            })

            compare(control.effectiveNetworkIcon, "network/arbitrum")
            compare(control.hasNetworkBadge, true)

            control.networkIconUrl = "network/ethereum"
            compare(control.effectiveNetworkIcon, "network/ethereum")
            compare(control.hasNetworkBadge, true)
        }

        // a popular asset has token entries but no balances; the catalog's
        // chain (fallbackChainId) must resolve the address chip then
        function test_addressChipWithoutBalances() {
            const tokens = Qt.createQmlObject("import QtQuick; ListModel {}", root)
            tokens.append({ chainId: 1, key: "1-" + root.tokenAddress })
            tokens.append({ chainId: 10, key: "10-0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" })

            const control = createTemporaryObject(delegateCmp, root, {
                tokensModel: tokens
            })

            // no balances and no catalog chain: nothing to resolve against
            compare(control.tokenAddress, "")
            compare(control.hasAddressChip, false)

            // the catalog chain picks the matching per-chain deployment
            control.fallbackChainId = 10
            compare(control.tokenAddress, "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            compare(control.hasAddressChip, true)

            control.fallbackChainId = 1
            compare(control.tokenAddress, root.tokenAddress)
            compare(control.hasAddressChip, true)

            // a chain the group has no entry for resolves to no chip
            control.fallbackChainId = 42161
            compare(control.tokenAddress, "")
            compare(control.hasAddressChip, false)
        }

        // a chain switch rebuilds the tokens submodel in place with an
        // unchanged row count; the address must follow the new content
        function test_addressFollowsTokensModelRebuild() {
            const tokens = Qt.createQmlObject("import QtQuick; ListModel {}", root)
            tokens.append({ chainId: 1, key: "1-" + root.tokenAddress })

            const control = createTemporaryObject(delegateCmp, root, {
                tokensModel: tokens,
                fallbackChainId: 1
            })
            compare(control.tokenAddress, root.tokenAddress)

            // the catalog now holds another chain's deployment; same row count
            control.fallbackChainId = 10
            compare(control.tokenAddress, "")
            tokens.setProperty(0, "chainId", 10)
            tokens.setProperty(0, "key", "10-0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")

            compare(control.tokenAddress, "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            compare(control.hasAddressChip, true)
        }

        function test_zeroAddressHasNoChip() {
            const control = createTemporaryObject(delegateCmp, root, {
                tokenAddress: Constants.zeroAddress
            })

            compare(control.hasAddressChip, false)

            control.tokenAddress = root.tokenAddress
            compare(control.hasAddressChip, true)
        }


        function test_hovered_highlighted_states() {
            const control = createTemporaryObject(delegateCmp, root)

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

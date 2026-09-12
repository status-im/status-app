import QtQuick
import QtTest

import shared.controls

// The shell carries the row's geometry before its content exists,
// so the list's contentHeight and scroll position depend on the shell's own
// height matching what the loaded row resolves to. These tests are that contract.
Item {
    id: root

    width: 600
    height: 400

    Component {
        id: shellComponent

        TokenDelegateShell {
            width: root.width

            sourceComponent: TokenDelegate {
                width: root.width

                name: "Ethereum"
                icon: "https://example.invalid/eth.png"
                balance: "1.23 ETH"
                marketBalance: "$4,321.00"
                marketDetailsAvailable: true
                marketCurrencyPrice: "$3,512.10"
                marketChangePct24hour: 1.5
            }
        }
    }

    Component {
        id: rowComponent

        TokenDelegate {
            width: root.width

            name: "Ethereum"
            icon: "https://example.invalid/eth.png"
            balance: "1.23 ETH"
            marketBalance: "$4,321.00"
            marketDetailsAvailable: true
            marketCurrencyPrice: "$3,512.10"
            marketChangePct24hour: 1.5
        }
    }

    TestCase {
        name: "TokenDelegateShell"
        when: windowShown

        function test_placeholderHeightMatchesTheRow() {
            const row = createTemporaryObject(rowComponent, root)
            verify(!!row)
            waitForRendering(row)

            const shell = createTemporaryObject(shellComponent, root)
            verify(!!shell)

            compare(shell.placeholderHeight, row.implicitHeight,
                    "the shell's placeholder height no longer matches the token row - "
                    + "the list geometry will jump as rows fill in")
        }

        function test_heightDoesNotChangeWhenTheContentArrives() {
            const shell = createTemporaryObject(shellComponent, root)
            verify(!!shell)

            verify(!shell.contentReady, "the content must not be built synchronously")
            const placeholderHeight = shell.height

            tryVerify(() => shell.contentReady)
            waitForRendering(shell)

            compare(shell.height, placeholderHeight,
                    "the row changed height when its content arrived")
            compare(shell.contentItem.height, placeholderHeight)
        }
    }
}

import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

// The shell carries the row's geometry before its content exists,
// so the list's contentHeight and scroll position depend on the shell's own
// height matching what the loaded row resolves to. These tests are that contract.
Item {
    id: root

    width: 400
    height: 400

    // The account row as LeftTabView configures it: title, subtitle and a 40px
    // identicon. StatusListItem's implicitHeight floor is what makes this 64.
    component AccountRow: StatusListItem {
        width: root.width

        title: "Account 0"
        subTitle: "1,234.56 USD"
        asset.emoji: "😃"
        asset.color: Theme.palette.primaryColor1
        asset.width: 40
        asset.height: 40
        asset.letterSize: 14
        asset.isLetterIdenticon: true
        asset.bgColor: Theme.palette.primaryColor3
        statusListItemTitle.font.weight: Font.Medium
    }

    Component {
        id: shellComponent

        WalletAccountDelegateShell {
            width: root.width

            sourceComponent: AccountRow {}
        }
    }

    Component {
        id: rowComponent

        AccountRow {}
    }

    TestCase {
        name: "WalletAccountDelegateShell"
        when: windowShown

        function test_placeholderHeightMatchesTheRow() {
            const row = createTemporaryObject(rowComponent, root)
            verify(!!row)
            waitForRendering(row)

            const shell = createTemporaryObject(shellComponent, root)
            verify(!!shell)

            compare(shell.placeholderHeight, row.implicitHeight,
                    "the shell's placeholder height no longer matches the account row - "
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

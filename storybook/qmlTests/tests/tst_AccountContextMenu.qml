import QtQuick
import QtTest

import AppLayouts.Wallet.views

import utils

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: menuComponent
        AccountContextMenu {}
    }

    SignalSpy {
        id: hideSpy
        signalName: "hideFromTotalBalanceClicked"
    }

    TestCase {
        name: "AccountContextMenu"
        when: windowShown

        property AccountContextMenu menu: null

        function cleanup() {
            hideSpy.target = null
            hideSpy.clear()
            if (!!menu) {
                menu.destroy()
                menu = null
            }
        }

        function createMenu(props) {
            cleanup()
            menu = createTemporaryObject(menuComponent, root, props)
            verify(!!menu)
            hideSpy.target = menu
            return menu
        }

        function watchMenu(hideFromTotalBalance) {
            return createMenu({
                address: "0xabc",
                name: "Watched",
                walletType: Constants.watchWalletType,
                hideFromTotalBalance: hideFromTotalBalance
            })
        }

        function hideAction() {
            return findChild(menu, "AccountMenu-HideFromTotalBalance_" + menu.name)
        }

        function test_watchAccountHideActionLabels() {
            watchMenu(false)
            verify(hideAction().enabled)
            compare(hideAction().text, qsTr("Exclude from balances and activity"))

            watchMenu(true)
            verify(hideAction().enabled)
            compare(hideAction().text, qsTr("Include in balances and activity"))
        }

        function test_regularAccountDisablesHideAction() {
            createMenu({
                address: "0xabc",
                name: "Account 1",
                walletType: Constants.generatedWalletType,
                hideFromTotalBalance: false
            })

            verify(!!hideAction())
            verify(!hideAction().enabled)
        }

        function test_triggerEmitsInvertedHideFlag() {
            watchMenu(true)
            hideAction().trigger()
            compare(hideSpy.count, 1)
            compare(hideSpy.signalArguments[0][0], false)
        }
    }
}

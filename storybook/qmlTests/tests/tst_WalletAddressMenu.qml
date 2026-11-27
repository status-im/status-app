import QtQuick
import QtTest

import StatusQ

import AppLayouts.Profile.popups

import utils

Item {
    id: root
    width: 600
    height: 600

    readonly property string address: "0xcDC2Ea3b6bA8FEd3a3402F8dB8b2fAb53E7B7421"

    ListModel {
        id: networks
        ListElement { chainId: 1; shortName: "eth"; chainName: "Mainnet"; isTest: false; iconUrl: ""; layer: 1 }
    }

    Component {
        id: menuComponent
        WalletAddressMenu {
            flatNetworks: networks
            selectedAccount: ({ address: root.address.toLowerCase(), mixedcaseAddress: root.address,
                                name: "Main", emoji: "", colorId: "" })
        }
    }

    SignalSpy {
        id: copySpy
        target: Global
        signalName: "copyOwnAddressRequested"
    }

    SignalSpy {
        id: qrSpy
        target: Global
        signalName: "openShowQRPopup"
    }

    TestCase {
        name: "WalletAddressMenu"
        when: windowShown

        function init() {
            copySpy.clear()
            qrSpy.clear()
        }

        function openMenu(props) {
            const menu = createTemporaryObject(menuComponent, root, props ?? {})
            verify(!!menu)
            menu.popup(root, 0, 0)
            tryCompare(menu, "opened", true)
            return menu
        }

        // Only an address that needs a password goes through the gate
        function test_copy_data() {
            return [
                { tag: "regular", reveal: false },
                { tag: "needs password", reveal: true },
            ]
        }
        function test_copy(data) {
            ClipboardUtils.setText("before")
            const menu = openMenu({ revealNeedsPassword: data.reveal })
            mouseClick(findChild(menu, "walletAddressMenuCopyAction"))
            compare(copySpy.count, data.reveal ? 1 : 0)
            compare(ClipboardUtils.text, data.reveal ? "before" : root.address)
            if (data.reveal)
                tryCompare(menu, "opened", false)
        }

        // The view-address modal gets the same restriction
        function test_qrPassesTheRestriction_data() {
            return [ { tag: "regular", reveal: false }, { tag: "needs password", reveal: true } ]
        }
        function test_qrPassesTheRestriction(data) {
            const menu = openMenu({ revealNeedsPassword: data.reveal })
            findChild(menu, "walletAddressMenuQrAction").trigger()
            compare(qrSpy.count, 1)
            compare(qrSpy.signalArguments[0][0].revealNeedsPassword, data.reveal)
        }
    }
}

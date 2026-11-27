import QtQuick
import QtTest

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.popups
import Models
import utils

Item {
    id: root
    width: 800
    height: 900

    readonly property string address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"

    Component {
        id: modalComponent
        ReceiveModal {
            parent: root
            accounts: WalletAccountsModel {}
            selectedAccount: ({ name: "Wallet", emoji: "", colorId: "primary",
                                address: root.address.toLowerCase(), mixedcaseAddress: root.address })
            switchingAccounsEnabled: false
            qrImageSource: ""
        }
    }

    SignalSpy { id: setPasswordSpy; signalName: "setPasswordRequested" }
    SignalSpy { id: shownSpy; signalName: "addressShown" }
    SignalSpy { id: copyGateSpy; target: Global; signalName: "copyOwnAddressRequested" }

    TestCase {
        name: "ReceiveModal"
        when: windowShown

        function init() {
            setPasswordSpy.clear()
            shownSpy.clear()
            copyGateSpy.clear()
            ClipboardUtils.setText("before")
        }

        function openModal(restricted) {
            const modal = createTemporaryObject(modalComponent, root, { revealNeedsPassword: restricted })
            verify(!!modal)
            setPasswordSpy.target = modal
            shownSpy.target = modal
            modal.open()
            tryCompare(modal, "opened", true)
            return modal
        }

        function test_regular() {
            const modal = openModal(false)
            const text = findChild(modal, "receiveModalAddressText")
            compare(text.text, root.address)
            compare(findChild(modal, "receiveModalSetPasswordButton").visible, false)
            verify(findChild(modal, "qrCodeImage").visible)

            mouseClick(findChild(modal, "receiveModalCopyButton"))
            compare(ClipboardUtils.text, root.address)
            compare(copyGateSpy.count, 0)
        }

        // Blurred QR with only a "Set password" button; the address is elided and copied through the gate
        function test_restricted() {
            const modal = openModal(true)
            const text = findChild(modal, "receiveModalAddressText")
            const elided = SQUtils.Utils.elideAndFormatWalletAddress(root.address)
            compare(text.text, elided)
            compare(text.Accessible.name, elided)
            verify(findChild(modal, "receiveModalQrBlur").visible)
            compare(findChild(modal, "qrCodeImage").visible, false)
            compare(findChild(modal, "receiveModalIdenticon").visible, false)

            const setPassword = findChild(modal, "receiveModalSetPasswordButton")
            verify(setPassword.visible)
            compare(setPassword.text, qsTr("Set password"))
            mouseClick(setPassword)
            compare(setPasswordSpy.count, 1)

            mouseClick(findChild(modal, "receiveModalCopyButton"))
            compare(copyGateSpy.count, 1)
            compare(copyGateSpy.signalArguments[0][0], root.address)
            compare(ClipboardUtils.text, "before")
        }

        // Reported as shown only once it really is
        function test_addressShown() {
            let modal = openModal(false)
            compare(shownSpy.count, 1)
            compare(shownSpy.signalArguments[0][0], root.address.toLowerCase())
            modal.close()
            tryCompare(modal, "opened", false)

            shownSpy.clear()
            modal = openModal(true)
            compare(shownSpy.count, 0)
            modal.revealNeedsPassword = false
            compare(shownSpy.count, 1)
        }
    }
}

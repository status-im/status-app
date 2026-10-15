import QtQuick
import QtTest

import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers

Item {
    id: root
    width: 800
    height: 800

    Component {
        id: componentUnderTest
        TransferOwnershipPopup {
            communityId: "community"
            communityName: "Test Community"
            communityLogo: ""
            token: TokenObject {
                name: "Owner-Test Community"
                symbol: "OWN"
                accountAddress: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
                chainId: 560048
                tokenAddress: "0x1111111111111111111111111111111111111111"
                artworkSource: ""
            }
            destroyOnClose: false
            modal: false
        }
    }

    SignalSpy {
        id: transferSpy
        signalName: "transferOwnershipRequested"
    }

    TestCase {
        name: "TransferOwnershipPopup"
        when: windowShown

        function test_ack_enables_send_and_emits() {
            const popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            transferSpy.target = popup

            const ack = findChild(popup, "transferOwnershipAckCheckBox")
            const send = findChild(popup, "sendOwnerTokenConfirmButton")
            verify(!!ack)
            verify(!!send)
            compare(send.enabled, false)

            ack.checked = true
            compare(send.enabled, true)

            popup.close()
        }
    }
}

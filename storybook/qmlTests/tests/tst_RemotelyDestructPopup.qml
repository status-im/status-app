import QtQuick
import QtTest

import AppLayouts.Communities.popups
import Models

Item {
    id: root
    width: 800
    height: 800

    ListModel {
        id: accountsModel
        ListElement {
            name: "Status account"
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            color: "red"
            emoji: "🔑"
            walletType: "generated"
        }
    }

    Component {
        id: componentUnderTest
        RemotelyDestructPopup {
            collectibleName: "Socks"
            chainName: "Hoodi"
            model: TokenHoldersModel {}
            accounts: accountsModel
            feeText: "0.01 ETH"
            feeErrorText: ""
            isFeeLoading: false
            destroyOnClose: false
            modal: false
        }
    }

    SignalSpy {
        id: destructSpy
        signalName: "remotelyDestructClicked"
    }

    TestCase {
        name: "RemotelyDestructPopup"
        when: windowShown

        function test_ui_and_confirm_disabled_until_fees() {
            const popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            destructSpy.target = popup

            compare(popup.feeLabel, "Remotely destruct Socks token on Hoodi")
            const confirm = findChild(popup, "remotelyDestructConfirmButton")
            verify(!!confirm)
            compare(confirm.enabled, false)

            popup.close()
        }
    }
}

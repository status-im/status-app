import QtQuick
import QtTest

import AppLayouts.Communities.popups

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
        BurnTokensPopup {
            communityName: "Test Community"
            tokenName: "Socks"
            remainingTokens: "9"
            multiplierIndex: 0
            isAsset: false
            tokenSource: ""
            chainName: "Hoodi"
            accounts: accountsModel
            feeText: "0.01 ETH"
            feeErrorText: ""
            isFeeLoading: false
            destroyOnClose: false
            modal: false
        }
    }

    SignalSpy {
        id: burnSpy
        signalName: "burnClicked"
    }

    TestCase {
        name: "BurnTokensPopup"
        when: windowShown

        function test_fee_label_and_all_remaining_option() {
            const popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            burnSpy.target = popup

            compare(popup.feeLabel, "Burn Socks token on Hoodi")
            verify(!!findChild(popup, "burnAllRemainingRadioButton"))
            verify(!!findChild(popup, "burnSpecificAmountRadioButton"))
            const confirm = findChild(popup, "burnTokensConfirmButton")
            verify(!!confirm)
            compare(confirm.enabled, false)

            popup.close()
        }
    }
}

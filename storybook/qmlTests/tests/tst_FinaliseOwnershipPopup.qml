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
        FinaliseOwnershipPopup {
            communityName: "Test Community"
            communityLogo: ""
            communityColor: "#FF0000"
            tokenSymbol: "OWN"
            tokenChainName: "Hoodi"
            accounts: accountsModel
            feeText: "0.01 ETH"
            feeErrorText: ""
            isFeeLoading: false
            destroyOnClose: false
            modal: false
        }
    }

    TestCase {
        name: "FinaliseOwnershipPopup"
        when: windowShown

        function test_initial_accept_and_fee_label() {
            const popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)

            compare(popup.feeLabel, "Update Test Community Community smart contract on Hoodi")
            const accept = findChild(popup, "finaliseOwnershipAcceptButton")
            verify(!!accept)
            compare(accept.text, "Finalise Test Community ownership")
            compare(accept.enabled, true)

            popup.close()
        }
    }
}

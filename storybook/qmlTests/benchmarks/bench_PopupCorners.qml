import QtQuick
import QtTest

import Models
import AppLayouts.Chat.popups
import AppLayouts.Wallet.popups

import Benchmark

/*
  Popups whose content is rounded by a layer effect, opened once: the
  receive modal (its QR code) and the pinned messages popup (its list,
  empty: the messages need the app's stores).

  Variants: receive, pinned (static).
*/
Item {
    id: root

    width: 1000
    height: 800

    property string popup: "receive"

    Component {
        id: receiveComponent
        ReceiveModal {
            accounts: WalletAccountsModel {}
            selectedAccount: ({
                name: "Wallet",
                emoji: "",
                colorId: "primary",
                address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                mixedcaseAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
            })
            switchingAccounsEnabled: false
            qrImageSource: Qt.resolvedUrl("../../testData/qr/profile.png")
        }
    }

    Component {
        id: pinnedComponent
        PinnedMessagesPopup {
            pinnedMessagesModel: ListModel {}
        }
    }

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 1
        isReady: item => item.popupItem && item.popupItem.opened

        delegate: Item {
            required property int index
            property var popupItem: null

            Component.onCompleted: {
                popupItem = (root.popup === "receive" ? receiveComponent : pinnedComponent).createObject(root)
                popupItem.open()
            }
            Component.onDestruction: if (popupItem) popupItem.destroy()
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(popup) {
            root.popup = popup
            runner.scenarios = ["static"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_receive() { bench("receive") }
        function test_pinned() { bench("pinned") }
    }
}

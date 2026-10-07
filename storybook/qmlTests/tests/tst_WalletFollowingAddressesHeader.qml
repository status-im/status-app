import QtQuick
import QtTest

import AppLayouts.Wallet.panels

Item {
    id: root
    width: 900
    height: 120

    ListModel {
        id: accounts
        ListElement {
            name: "Account 1"
            address: "0x1111111111111111111111111111111111111111"
            emoji: "👛"
            colorId: "1"
            walletType: ""
        }
        ListElement {
            name: "Account 2"
            address: "0x2222222222222222222222222222222222222222"
            emoji: "🐷"
            colorId: "2"
            walletType: ""
        }
    }

    Component {
        id: headerComponent

        WalletFollowingAddressesHeader {
            width: 900
            accountsModel: accounts
            lastReloadedTime: "just now"
        }
    }

    TestCase {
        name: "WalletFollowingAddressesHeader"
        when: windowShown

        function spyOn(header, signalName) {
            const spy = Qt.createQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = header
            spy.signalName = signalName
            return spy
        }

        function test_findAFriend_emitsAddViaEFP() {
            const header = createTemporaryObject(headerComponent, root)
            const spy = spyOn(header, "addViaEFPClicked")
            const button = findChild(header, "walletHeaderButton")
            verify(button)
            waitForRendering(header)
            mouseClick(button)
            compare(spy.count, 1)
        }

        function test_reload_emitsWhenThrottleIsIdleAndNotLoading() {
            const header = createTemporaryObject(headerComponent, root)
            const spy = spyOn(header, "reloadRequested")
            const button = findChild(header, "followingAddressesReloadButton")
            const throttle = findChild(header, "followingAddressesReloadThrottle")
            verify(button)
            verify(throttle)
            throttle.stop()
            tryCompare(button, "interactive", true)
            mouseClick(button)
            compare(spy.count, 1)
        }

        function test_accountChange_emitsSelectedAddress() {
            const header = createTemporaryObject(headerComponent, root)
            const spy = spyOn(header, "accountChanged")
            const selector = findChild(header, "accountSelector")
            verify(selector)
            selector.selectedAddress = "0x2222222222222222222222222222222222222222"
            tryCompare(spy, "count", 1)
            compare(spy.signalArguments[0][0], "0x2222222222222222222222222222222222222222")
        }
    }
}

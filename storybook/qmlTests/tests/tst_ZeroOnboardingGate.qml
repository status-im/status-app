import QtQuick
import QtTest

import StatusQ

import utils
import mainui

Item {
    id: root

    Component {
        id: gateComponent
        ZeroOnboardingGate {
            zeroOnboarded: false
        }
    }

    SignalSpy {
        id: passwordRequiredSpy
        signalName: "passwordRequired"
    }

    SignalSpy {
        id: openLinkSpy
        target: Global
        signalName: "requestOpenLink"
    }

    TestCase {
        name: "ZeroOnboardingGate"

        readonly property string address: "0x1cd2a8f3b4e5d6c7a8b9c0d1e2f3a4b5c6d712b5"
        readonly property string link: "https://etherscan.io/address/0x1cd2a8f3b4e5d6c7a8b9c0d1e2f3a4b5c6d712b5"

        function init() {
            passwordRequiredSpy.clear()
            openLinkSpy.clear()
            ClipboardUtils.setText("before")
        }

        function create(zeroOnboarded) {
            const gate = createTemporaryObject(gateComponent, root, { zeroOnboarded })
            verify(!!gate)
            passwordRequiredSpy.target = gate
            return gate
        }

        function setPassword() {
            passwordRequiredSpy.signalArguments[0][1]("ValidPass1!")
        }

        function test_copyRegular() {
            create(false)
            Global.copyOwnAddressRequested(address)
            compare(passwordRequiredSpy.count, 0)
            compare(ClipboardUtils.text, address)
        }

        function test_copyAsksForPasswordThenCopies() {
            create(true)
            Global.copyOwnAddressRequested(address)
            compare(passwordRequiredSpy.count, 1)
            compare(passwordRequiredSpy.signalArguments[0][0], qsTr("Set password to copy address"))
            compare(ClipboardUtils.text, "before")

            setPassword()
            compare(ClipboardUtils.text, address)
        }

        function test_copyHasNoCancelHandler() {
            create(true)
            Global.copyOwnAddressRequested(address)
            verify(!passwordRequiredSpy.signalArguments[0][2])
            compare(ClipboardUtils.text, "before")
        }

        function test_link_data() {
            return [
                { tag: "regular", zero: false, asked: 0, opened: 1 },
                { tag: "zero-onboarded", zero: true, asked: 1, opened: 0 },
            ]
        }
        function test_link(data) {
            create(data.zero)
            Global.openOwnAddressLinkRequested(link)
            compare(passwordRequiredSpy.count, data.asked)
            compare(openLinkSpy.count, data.opened)
            if (!data.asked)
                return
            compare(passwordRequiredSpy.signalArguments[0][0], "")
            setPassword()
            compare(openLinkSpy.count, 1)
            compare(openLinkSpy.signalArguments[0][0], link)
        }

        function test_actionNeedingPassword_data() {
            return [
                { tag: "regular", zero: false, asked: 0, ran: 1 },
                { tag: "zero-onboarded", zero: true, asked: 1, ran: 0 },
            ]
        }
        function test_actionNeedingPassword(data) {
            create(data.zero)
            let ran = 0
            let cancelled = 0
            Global.passwordRequiredFor(() => ran++, () => cancelled++)
            compare(passwordRequiredSpy.count, data.asked)
            compare(ran, data.ran)
            if (!data.asked)
                return
            passwordRequiredSpy.signalArguments[0][2]()
            compare(cancelled, 1)
            setPassword()
            compare(ran, 1)
        }
    }
}

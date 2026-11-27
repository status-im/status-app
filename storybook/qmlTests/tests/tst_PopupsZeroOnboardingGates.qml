import QtQuick
import QtTest

import AppLayouts.Profile.stores
import utils
import mainui

import "helpers"

Item {
    id: root
    width: 800
    height: 600

    PopupsTestFixture {
        id: fixture
        popupParent: root
    }

    PrivacyStore {
        id: privacyStoreStub
        property bool zeroOnboarded: false
    }

    // Popups asks through Global; the gate in AppMain serves it
    ZeroOnboardingGate {
        id: gate
        zeroOnboarded: privacyStoreStub.zeroOnboarded
    }

    SignalSpy {
        id: passwordRequiredSpy
        target: gate
        signalName: "passwordRequired"
    }

    TestCase {
        name: "PopupsZeroOnboardingGates"
        when: windowShown

        function init() {
            fixture.prepare(this)
            fixture.popups.privacyStore = privacyStoreStub
            privacyStoreStub.zeroOnboarded = false
            passwordRequiredSpy.clear()
        }

        function cleanup() {
            const popups = fixture.popups.item
            if (!popups)
                return
            popups.closePopup()
            tryVerify(() => popups.activePopupComponents.length === 0)
        }

        // Popups loads asynchronously: requests run once it is there
        function waitForPopups() {
            tryVerify(() => !!fixture.popups.item)
        }

        // Buying crypto and payment requests reveal an own address: a password comes first
        function test_gatedPopupsAskForPasswordFirst_data() {
            return [ { tag: "buy crypto", buy: true }, { tag: "payment request", buy: false } ]
        }
        function test_gatedPopupsAskForPasswordFirst(data) {
            privacyStoreStub.zeroOnboarded = true
            if (data.buy)
                Global.openBuyCryptoModalRequested({})
            else
                Global.openPaymentRequestModalRequested(() => {}, () => {})
            waitForPopups()
            compare(passwordRequiredSpy.count, 1)
            compare(fixture.popups.item.activePopupComponents.length, 0)
        }

        // The caller gets no popup when the password is cancelled, so it can reset its own state
        function test_paymentRequestCancelledReportsNoPopup() {
            privacyStoreStub.zeroOnboarded = true
            let popups = []
            Global.openPaymentRequestModalRequested(() => {}, popup => popups.push(popup))
            waitForPopups()
            passwordRequiredSpy.signalArguments[0][2]()
            compare(popups.length, 1)
            compare(popups[0], null)
        }

        function test_gatedPopupsOpenAfterPassword_data() {
            return [ { tag: "buy crypto", buy: true }, { tag: "payment request", buy: false } ]
        }
        function test_gatedPopupsOpenAfterPassword(data) {
            privacyStoreStub.zeroOnboarded = true
            if (data.buy)
                Global.openBuyCryptoModalRequested({})
            else
                Global.openPaymentRequestModalRequested(() => {}, () => {})
            waitForPopups()
            passwordRequiredSpy.signalArguments[0][1]("ValidPass1!")
            compare(fixture.popups.item.activePopupComponents.length, 1)
        }

        function test_gatedPopupsOpenAtOnceForRegularProfile_data() {
            return [ { tag: "buy crypto", buy: true }, { tag: "payment request", buy: false } ]
        }
        function test_gatedPopupsOpenAtOnceForRegularProfile(data) {
            if (data.buy)
                Global.openBuyCryptoModalRequested({})
            else
                Global.openPaymentRequestModalRequested(() => {}, () => {})
            waitForPopups()
            compare(passwordRequiredSpy.count, 0)
            compare(fixture.popups.item.activePopupComponents.length, 1)
        }
    }
}

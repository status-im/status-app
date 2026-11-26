import QtQuick
import QtTest

import shared.popups.authentication.stores as AuthStores
import shared.popups.signing.stores as SignStores

import mainui

Item {
    id: root
    width: 400
    height: 400

    property var calls: []

    AuthStores.AuthenticationStore {
        id: authenticationStoreStub

        property string keycardKeyUid: "uid_keycard"

        function isKeypairMigratedToColdWallet(keyUid) {
            root.calls.push(`auth.isKeypairMigratedToColdWallet:${keyUid}`)
            return keyUid === keycardKeyUid
        }

        function prepare() { root.calls.push("auth.prepare") }
        function passwordProvided(keyUid, password) { root.calls.push(`auth.passwordProvided:${keyUid}:${password}`) }
        function teardown() { root.calls.push("auth.teardown") }
    }

    SignStores.SigningStore {
        id: signingStoreStub

        property string signature: "0xsig"

        function prepare() { root.calls.push("sign.prepare") }
        function passwordProvided(keyUid, password) { root.calls.push(`sign.passwordProvided:${keyUid}:${password}`) }
        function signMessage(address, password, txHash) {
            root.calls.push(`sign.signMessage:${address}:${password}:${txHash}`)
            return signature
        }
        function teardown() { root.calls.push("sign.teardown") }
    }

    Component {
        id: componentUnderTest
        ZeroOnboardingAuthentication {
            authenticationStore: authenticationStoreStub
            signingStore: signingStoreStub
        }
    }

    SignalSpy {
        id: passwordRequiredSpy
        signalName: "passwordRequired"
    }

    SignalSpy {
        id: authenticatedSpy
        signalName: "authenticated"
    }

    SignalSpy {
        id: signedSpy
        signalName: "signed"
    }

    SignalSpy {
        id: signingFailedSpy
        signalName: "signingFailed"
    }

    TestCase {
        name: "ZeroOnboardingAuthentication"
        when: windowShown

        readonly property string password: "ValidPass1!"

        function init() {
            root.calls = []
            signingStoreStub.signature = "0xsig"
            authenticationStoreStub.d.ready = false
            passwordRequiredSpy.clear()
            authenticatedSpy.clear()
            signedSpy.clear()
            signingFailedSpy.clear()
        }

        function create() {
            const gate = createTemporaryObject(componentUnderTest, root)
            verify(!!gate)
            passwordRequiredSpy.target = gate
            authenticatedSpy.target = gate
            signedSpy.target = gate
            signingFailedSpy.target = gate
            return gate
        }

        function request(index) {
            return passwordRequiredSpy.signalArguments[index ?? 0]
        }

        function test_authenticationAsksForPasswordFirst() {
            const gate = create()
            verify(gate.authenticate("addAccount", "uid_zero"))

            compare(passwordRequiredSpy.count, 1)
            compare(root.calls, ["auth.prepare", "auth.isKeypairMigratedToColdWallet:uid_zero", "auth.teardown"])
            compare(authenticatedSpy.count, 0)
        }

        // The action continues with the new password, without a second prompt
        function test_authenticationContinuesWithNewPassword() {
            const gate = create()
            gate.authenticate("addAccount", "uid_zero")
            root.calls = []
            request()[0](password)

            compare(root.calls, ["auth.prepare", `auth.passwordProvided:uid_zero:${password}`, "auth.teardown"])
            compare(authenticatedSpy.count, 1)
            compare(Array.from(authenticatedSpy.signalArguments[0]), ["addAccount", password, "uid_zero"])
        }

        // Same as closing the authentication popup today: no result at all
        function test_cancelledAuthenticationEmitsNothing() {
            const gate = create()
            gate.authenticate("addAccount", "uid_zero")
            root.calls = []
            verify(!request()[1])
            compare(root.calls, [])
            compare(authenticatedSpy.count, 0)
        }

        function test_signingContinuesWithNewPassword() {
            const gate = create()
            verify(gate.sign("walletSend", "uid_zero", "0xhash", "m/44", "0xaddr"))
            compare(passwordRequiredSpy.count, 1)
            root.calls = []

            request()[0](password)

            compare(root.calls, ["sign.prepare", `sign.passwordProvided:uid_zero:${password}`,
                                 `sign.signMessage:0xaddr:${password}:0xhash`, "sign.teardown"])
            tryCompare(signedSpy, "count", 1)
            compare(Array.from(signedSpy.signalArguments[0]), ["walletSend", "0xsig", "uid_zero", "m/44", "0xaddr"])
            compare(signingFailedSpy.count, 0)
        }

        // Same as closing the signing popup today: an empty signature
        function test_cancelledSigningEmitsEmptySignature() {
            const gate = create()
            gate.sign("walletSend", "uid_zero", "0xhash", "m/44", "0xaddr")
            root.calls = []
            request()[1]()

            tryCompare(signedSpy, "count", 1)
            compare(Array.from(signedSpy.signalArguments[0]), ["walletSend", "", "uid_zero", "m/44", "0xaddr"])
            compare(root.calls, [])
        }

        function test_failedSigningEmitsEmptySignature() {
            signingStoreStub.signature = ""
            const gate = create()
            gate.sign("walletSend", "uid_zero", "0xhash", "m/44", "0xaddr")
            root.calls = []
            request()[0](password)

            tryCompare(signedSpy, "count", 1)
            compare(signedSpy.signalArguments[0][1], "")
            compare(signingFailedSpy.count, 1)
            verify(root.calls.includes("sign.teardown"))
        }
    
        // A Keycard key pair is unlocked with the card's PIN: the regular prompt handles it
        function test_keycardKeyPairIsLeftToTheRegularPrompt_data() {
            return [ { tag: "authentication", sign: false }, { tag: "signing", sign: true } ]
        }
        function test_keycardKeyPairIsLeftToTheRegularPrompt(data) {
            const gate = create()
            const handled = data.sign ? gate.sign("walletSend", "uid_keycard", "0xhash", "m/44", "0xaddr")
                                      : gate.authenticate("addAccount", "uid_keycard")
            verify(!handled)
            compare(passwordRequiredSpy.count, 0)
        }

        // A prompt that already holds the module keeps it
        function test_keycardCheckReusesAnOpenModule() {
            authenticationStoreStub.d.ready = true
            const gate = create()
            gate.authenticate("addAccount", "uid_zero")
            compare(root.calls, ["auth.isKeypairMigratedToColdWallet:uid_zero"])
        }
}
}

import QtQuick
import QtQuick.Controls

import QtTest

import StatusQ

import shared.popups.auth_sign_base 1.0

import utils

Item {
    id: root

    width: 480
    height: 520

    Component {
        id: componentUnderTest

        PopupBase {
            reason: "testing"
            keyUid: "key-uid-1"

            keychain: Keychain {}

            keycardState: Constants.keycard.state.ready
            keycardUid: "keycard-uid-1"
            remainingPinAttempts: 3
            userProfileKeyUid: "key-uid-1"
            userProfilePublicKey: "0xpub"
            userProfileMigratedToColdWallet: true
            isKeycardKeyPair: true

            btnActionName: "Authenticate"
            btnPasswordActionAndUpdateName: "Update password & authenticate"
            btnPinActionAndUpdateName: "Update PIN & authenticate"

            closePolicy: Popup.NoAutoClose
        }
    }

    Component {
        id: mockedKeychainComponent

        // Shadows the C++ members so no real OS keychain/biometrics is touched
        Keychain {
            property int requestCount: 0
            readonly property bool available: true
            function hasCredential(account) {
                return account === "key-uid-1" ? Keychain.StatusSuccess
                                               : Keychain.StatusNotFound
            }
            function requestGetCredential(reason, account) {
                requestCount++
                return Keychain.StatusSuccess
            }
        }
    }

    TestCase {
        name: "AuthSignPopupBase_biometricsAutoStart"
        when: windowShown

        property var popup: null
        property var mockKeychain: null

        function init() {
            mockKeychain = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!mockKeychain)
        }

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function test_autoStartsForProfileKeycardKeyPair() {
            popup = createTemporaryObject(componentUnderTest, root, { keychain: mockKeychain })
            verify(!!popup)
            popup.open()

            tryCompare(mockKeychain, "requestCount", 1)
        }

        // SignPopup's externalAuthorization can only settle to its final value after the store
        // gets ready — the gate turning on late must still auto-start biometrics.
        function test_autoStartsWhenGateTurnsOnLate() {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              externalAuthorization: true
                                          })
            verify(!!popup)
            popup.open()

            waitForRendering(popup.contentItem)
            compare(mockKeychain.requestCount, 0)

            popup.externalAuthorization = false
            tryCompare(mockKeychain, "requestCount", 1)
        }

        // Biometrics holds the profile credential only: signing with a non-profile keycard
        // keypair must go through its own keycard, never through biometrics.
        function test_neverStartsForNonProfileKeycardKeyPair() {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              keyUid: "other-keypair-uid",
                                              externalAuthorization: true
                                          })
            verify(!!popup)
            popup.open()

            waitForRendering(popup.contentItem)

            // mimic the store-ready flip that re-resolves externalAuthorization for keycard keypairs
            popup.externalAuthorization = false
            waitForRendering(popup.contentItem)

            compare(mockKeychain.requestCount, 0)

            const bioButton = findChild(popup, "useBiometricsButton")
            verify(!!bioButton)
            verify(!bioButton.visible)
        }
    }

    TestCase {
        name: "AuthSignPopupBase_keycardPin"
        when: windowShown

        property var popup: null

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        // The PIN used for the keycard action must be exposed via lastUsedPin, so that
        // concrete popups (AuthenticationPopup) can propagate it on success and the
        // enable-biometrics handlers store the PIN (not the encryption public key).
        function test_lastUsedPinExposesEnteredPin() {
            let capturedKeyUid = ""
            let capturedPin = ""

            popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.performKeycardAction = (keyUid, pin, pairingPassword) => {
                capturedKeyUid = keyUid
                capturedPin = pin
            }
            popup.open()

            compare(popup.lastUsedPin, "")

            tryVerify(() => !!findChild(popup, "keycardAuthPinInput"))
            const pinInput = findChild(popup, "keycardAuthPinInput")
            pinInput.setPin("123456") // completing the PIN auto-submits the keycard action

            compare(capturedKeyUid, "key-uid-1")
            compare(capturedPin, "123456")
            compare(popup.lastUsedPin, "123456")

            popup.handleKeycardSuccess()
            compare(popup.lastUsedPin, "123456")
        }
    }
}

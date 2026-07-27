import QtQuick
import QtTest

import StatusQ

import shared.popups.auth_sign_base 1.0

Item {
    id: root
    width: 600
    height: 400

    Keychain {
        id: stubKeychain
    }

    Component {
        id: popupComponent
        PopupBase {
            reason: "test"
            keyUid: ""
            keychain: stubKeychain
            keycardState: "ready"
            remainingPinAttempts: 3
            userProfileKeyUid: "profile-key-uid"
            userProfilePublicKey: "0xprofile"
            userProfileMigratedToColdWallet: false
            isKeycardKeyPair: false
            btnActionName: "Go"
            btnPasswordActionAndUpdateName: "Update & go"
            btnPinActionAndUpdateName: "PIN & go"
            visible: false
        }
    }

    TestCase {
        name: "PopupBaseKeycardSelection"
        when: windowShown

        property PopupBase popup: null

        function init() {
            popup = createTemporaryObject(popupComponent, root)
            verify(!!popup)
        }

        function test_hotKeypairUsesPasswordWhenProfileIsHot() {
            popup.purpose = PopupBase.Purpose.Signing
            popup.keyUid = "hot-key-uid"
            popup.isKeycardKeyPair = false
            popup.userProfileMigratedToColdWallet = false
            popup.userProfileKeyUid = "profile-key-uid"

            compare(popup.useKeycard, false)
        }

        // Authentication with a Keycard profile has no password to fall back on,
        // so authenticating against the profile Keycard is intended here.
        function test_authenticationWithColdProfileUsesProfileKeycard() {
            popup.purpose = PopupBase.Purpose.Authentication
            popup.keyUid = "hot-seed-key-uid"
            popup.isKeycardKeyPair = false
            popup.userProfileMigratedToColdWallet = true
            popup.userProfileKeyUid = "profile-key-uid"

            compare(popup.useKeycard, true)
            compare(popup.useKeyUid, "profile-key-uid")
        }

        // Bugbot high: signing a hot keypair while the profile is on a Keycard
        // routes performKeycardAction to the profile keyUid, i.e. asks the card
        // to sign for a key it does not hold. Whatever the fix is (password path
        // or Keycard auth + keystore signing), a signature request must never be
        // routed to a different keypair's card.
        function test_signingNeverRoutesHotKeypairToProfileKeycard() {
            popup.purpose = PopupBase.Purpose.Signing
            popup.keyUid = "hot-seed-key-uid"
            popup.isKeycardKeyPair = false
            popup.userProfileMigratedToColdWallet = true
            popup.userProfileKeyUid = "profile-key-uid"

            verify(!popup.useKeycard || popup.useKeyUid === popup.keyUid,
                   "signing must not send a hot keypair's tx to the profile Keycard")
        }

        function test_keycardKeypairUsesKeycardAndOwnKeyUid() {
            popup.purpose = PopupBase.Purpose.Signing
            popup.keyUid = "cold-key-uid"
            popup.isKeycardKeyPair = true
            popup.userProfileMigratedToColdWallet = false
            popup.userProfileKeyUid = "profile-key-uid"

            compare(popup.useKeycard, true)
            compare(popup.useKeyUid, "cold-key-uid")
        }

        function test_profileKeypairOnKeycardUsesProfileKeyUid() {
            popup.purpose = PopupBase.Purpose.Signing
            popup.keyUid = "profile-key-uid"
            popup.isKeycardKeyPair = true
            popup.userProfileMigratedToColdWallet = true
            popup.userProfileKeyUid = "profile-key-uid"

            compare(popup.useKeycard, true)
            compare(popup.useKeyUid, "profile-key-uid")
        }
    }
}

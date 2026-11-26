import QtQuick
import QtTest

import StatusQ

import AppLayouts.Profile.stores
import shared.popups.authentication.stores as AuthStores
import utils

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

    AuthStores.AuthenticationStore {
        id: authenticationStoreStub

        property bool onKeycard: false

        function prepare() {}
        function teardown() {}
        function passwordProvided(keyUid, password) {}
        function isKeypairMigratedToColdWallet(keyUid) { return onKeycard }
    }

    SecureStorage {
        id: secureStorageStub

        property int deleteStatus: SecureStorage.StatusSuccess
        property int deleteCalls: 0

        function deleteCredential(account) {
            deleteCalls++
            return deleteStatus
        }
    }

    SignalSpy {
        id: authenticationResultSpy
        target: Global
        signalName: "authenticationResult"
    }

    SignalSpy {
        id: passwordRequiredSpy
        target: fixture.popups
        signalName: "passwordRequired"
    }

    TestCase {
        name: "PopupsZeroOnboardingInterception"
        when: windowShown

        function init() {
            fixture.prepare(this)
            fixture.popups.privacyStore = privacyStoreStub
            fixture.popups.secureStorage = secureStorageStub
            privacyStoreStub.zeroOnboarded = false
            passwordRequiredSpy.clear()
            authenticationResultSpy.clear()
            authenticationStoreStub.onKeycard = false
            secureStorageStub.deleteStatus = SecureStorage.StatusSuccess
            secureStorageStub.deleteCalls = 0
        }

        // Popups loads asynchronously: requests run once it is there
        function request(call) {
            fixture.popups.invoke(() => {
                fixture.popups.item.zeroOnboardingAuthentication.authenticationStore = authenticationStoreStub
                call(fixture.popups.item)
            })
            tryVerify(() => !!fixture.popups.item)
        }

        function cleanup() {
            const popups = fixture.popups.item
            if (!popups)
                return
            popups.closePopup()
            tryVerify(() => popups.activePopupComponents.length === 0)
        }

        function startKeycardMove() {
            request((popups) => popups.openKeycardManagementPopup(Constants.keycard.flow.moveProfileKeyPair, "", "", "", "", false))
        }

        function authenticateKeycardMove() {
            request((popups) => popups.openAuthenticationPopup(Constants.keycard.flow.moveProfileKeyPair, "", false))
        }

        // The saved credential is the only key until a password is set, so it stays while the flow starts
        function test_keycardMoveStartsWithoutPasswordOrRemoval() {
            privacyStoreStub.zeroOnboarded = true
            startKeycardMove()
            compare(passwordRequiredSpy.count, 0)
            compare(secureStorageStub.deleteCalls, 0)
        }

        function test_keycardMoveRemovesCredentialAtStartForRegularProfile() {
            startKeycardMove()
            compare(secureStorageStub.deleteCalls, 1)
        }

        // The move's authentication sets the password, then removes the credential, then continues
        function test_keycardMoveContinuesAfterPasswordAndRemoval() {
            privacyStoreStub.zeroOnboarded = true
            authenticateKeycardMove()
            compare(passwordRequiredSpy.count, 1)
            compare(secureStorageStub.deleteCalls, 0)

            passwordRequiredSpy.signalArguments[0][1]("ValidPass1!")
            compare(secureStorageStub.deleteCalls, 1)
            compare(authenticationResultSpy.count, 1)
            compare(authenticationResultSpy.signalArguments[0][0], Constants.keycard.flow.moveProfileKeyPair)
            compare(authenticationResultSpy.signalArguments[0][1], "ValidPass1!")
        }

        function test_keycardMoveStopsWhenRemovalUnverified() {
            privacyStoreStub.zeroOnboarded = true
            secureStorageStub.deleteStatus = SecureStorage.StatusUnavailable
            authenticateKeycardMove()
            passwordRequiredSpy.signalArguments[0][1]("ValidPass1!")
            compare(authenticationResultSpy.count, 0)
        }

        // A retry after a failed removal authenticates normally: the removal guards it too
        function test_keycardMoveAuthenticationNeedsRemoval_data() {
            return [
                { tag: "removed", status: SecureStorage.StatusSuccess, opened: 1 },
                { tag: "not removed", status: SecureStorage.StatusUnavailable, opened: 0 },
            ]
        }
        function test_keycardMoveAuthenticationNeedsRemoval(data) {
            secureStorageStub.deleteStatus = data.status
            authenticateKeycardMove()
            compare(secureStorageStub.deleteCalls, 1)
            compare(fixture.popups.item.activePopupComponents.length, data.opened)
        }

        function test_routing_data() {
            return [
                { tag: "authentication, zero-onboarded", zero: true, keycard: false, sign: false, asked: 1, opened: 0 },
                { tag: "signing, zero-onboarded", zero: true, keycard: false, sign: true, asked: 1, opened: 0 },
                { tag: "authentication, regular", zero: false, keycard: false, sign: false, asked: 0, opened: 1 },
                { tag: "signing, regular", zero: false, keycard: false, sign: true, asked: 0, opened: 1 },
                { tag: "authentication, zero-onboarded, Keycard key pair", zero: true, keycard: true, sign: false, asked: 0, opened: 1 },
                { tag: "signing, zero-onboarded, Keycard key pair", zero: true, keycard: true, sign: true, asked: 0, opened: 1 },
            ]
        }
        function test_routing(data) {
            privacyStoreStub.zeroOnboarded = data.zero
            authenticationStoreStub.onKeycard = data.keycard
            request((popups) => {
                if (data.sign)
                    popups.openSigningPopup("walletSend", "uid_zero", "0xhash", "m/44", "0xaddr")
                else
                    popups.openAuthenticationPopup("addAccount", "uid_zero", false)
            })
            compare(passwordRequiredSpy.count, data.asked)
            compare(fixture.popups.item.activePopupComponents.length, data.opened)
        }
    }
}

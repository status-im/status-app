import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ

import AppLayouts.Profile.stores

import mainui.Handlers

Item {
    id: root
    width: 800
    height: 900

    PrivacyStore {
        id: privacyStoreStub

        readonly property string keyUid: "uid_zero"
        property var setPasswordCalls: []
        property var stayLoggedInCalls: []

        signal profilePasswordSet(bool success, string errorMsg)

        function setProfilePassword(password) { setPasswordCalls.push(password) }
        function setStayLoggedIn(value) { stayLoggedInCalls.push(value) }
        function getBiometricCredentialForStorage(keyUid, password) { return "bio:" + password }
        function getStayLoggedInCredentialForStorage(keyUid, password) { return "dek:" + password }
    }

    SecureStorage {
        id: secureStorageStub

        property bool available: true
        property var deleteCalls: []
        property int deleteStatus: SecureStorage.StatusSuccess
        property int hasStatus: SecureStorage.StatusSuccess
        property int setStatus: SecureStorage.StatusSuccess
        property var setCalls: []

        function hasCredential(account) { return hasStatus }
        function setCredential(account, credential) {
            setCalls.push({ account, credential })
            return setStatus
        }

        function deleteCredential(account) {
            deleteCalls.push(account)
            return deleteStatus
        }
    }

    Keychain {
        id: keychainStub

        readonly property bool available: true
        property var saveCalls: []

        function saveCredential(account, credential) {
            saveCalls.push({ account, credential })
            return Keychain.StatusSuccess
        }
    }

    Component {
        id: handlerComponent

        CreatePasswordPopupHandler {
            popupParent: root
            passwordStrengthScoreFunction: (password) => 4
            privacyStore: privacyStoreStub
            secureStorage: secureStorageStub
            keychain: keychainStub
        }
    }

    TestCase {
        name: "CreatePasswordPopupHandler"
        when: windowShown

        readonly property string validPassword: "ValidPass1!"

        property var successCalls: []
        property int cancelCalls: 0

        function init() {
            privacyStoreStub.setPasswordCalls = []
            privacyStoreStub.stayLoggedInCalls = []
            secureStorageStub.deleteCalls = []
            secureStorageStub.deleteStatus = SecureStorage.StatusSuccess
            secureStorageStub.available = true
            secureStorageStub.hasStatus = SecureStorage.StatusSuccess
            secureStorageStub.setStatus = SecureStorage.StatusSuccess
            secureStorageStub.setCalls = []
            keychainStub.saveCalls = []
            successCalls = []
            cancelCalls = 0
        }

        function cleanup() {
            const p = popup()
            if (p) {
                p.loading = false
                p.close()
                tryVerify(() => !popup())
            }
        }

        function popup() {
            return findChild(root, "createPasswordPopup")
        }

        function require(handler, title) {
            handler.requirePassword(title ?? "", (password) => successCalls.push(password), () => cancelCalls++)
            tryVerify(() => !!popup() && popup().opened)
            return popup()
        }

        function submit(p, clickStay, clickBio) {
            if (clickStay)
                mouseClick(findChild(p, "stayLoggedInSwitch"))
            if (clickBio)
                mouseClick(findChild(p, "biometricsSwitch"))
            findChild(p, "passwordViewNewPassword").text = validPassword
            findChild(p, "passwordViewNewPasswordConfirm").text = validPassword
            mouseClick(findChild(p, "createPasswordConfirmButton"))
        }

        function test_titleDefaultsAndOverrides() {
            const handler = createTemporaryObject(handlerComponent, root)
            let p = require(handler)
            compare(p.title, qsTr("Create profile password"))
            p.close()
            tryVerify(() => !popup())

            p = require(handler, "Set password to copy address")
            compare(p.title, "Set password to copy address")
        }

        function test_submitSetsPasswordAndWaits() {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p)

            compare(privacyStoreStub.setPasswordCalls, [validPassword])
            verify(p.loading)
            verify(p.opened)
            compare(successCalls.length, 0)
        }

        function test_successClosesThenContinues() {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p)
            privacyStoreStub.profilePasswordSet(true, "")

            tryVerify(() => !popup())
            tryCompare(successCalls, "length", 1)
            compare(successCalls[0], validPassword)
            compare(cancelCalls, 0)
        }

        function test_failureKeepsPopupWithError() {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p)
            privacyStoreStub.profilePasswordSet(false, "backend failed")

            verify(p.opened)
            verify(!p.loading)
            verify(p.errorText !== "")
            compare(successCalls.length, 0)
            compare(keychainStub.saveCalls.length, 0)
        }

        function test_cancelCancelsTheAction() {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            mouseClick(findChild(p, "createPasswordCancelButton"))

            tryVerify(() => !popup())
            compare(cancelCalls, 1)
            compare(successCalls.length, 0)
            compare(privacyStoreStub.setPasswordCalls.length, 0)
        }

        function test_resultOfAnotherRequestIgnored() {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            privacyStoreStub.profilePasswordSet(true, "")

            verify(p.opened)
            compare(successCalls.length, 0)
        }

        function test_secondRequestWhileOpenIsCancelled() {
            const handler = createTemporaryObject(handlerComponent, root)
            require(handler)
            let secondCancelled = false
            handler.requirePassword("", () => {}, () => secondCancelled = true)

            verify(secondCancelled)
            compare(cancelCalls, 0)
        }

        // The toggles are applied only once the password is set
        function test_togglesAppliedAfterSuccess_data() {
            return [
                { tag: "both on", clickStay: false, clickBio: false, deletes: [], stay: [], saves: 1 },
                { tag: "stay off", clickStay: true, clickBio: false, deletes: ["uid_zero"], stay: [false], saves: 1 },
                { tag: "biometrics off", clickStay: false, clickBio: true, deletes: [], stay: [], saves: 0 },
            ]
        }
        function test_togglesAppliedAfterSuccess(data) {
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p, data.clickStay, data.clickBio)
            compare(secureStorageStub.deleteCalls.length, 0)
            compare(keychainStub.saveCalls.length, 0)

            privacyStoreStub.profilePasswordSet(true, "")

            compare(secureStorageStub.deleteCalls, data.deletes)
            compare(privacyStoreStub.stayLoggedInCalls, data.stay)
            compare(keychainStub.saveCalls.length, data.saves)
            if (data.saves) {
                compare(keychainStub.saveCalls[0].account, "uid_zero")
                compare(keychainStub.saveCalls[0].credential, "bio:" + validPassword)
            }
        }

        // A credential lost after creation is saved again when the user keeps automatic login
        function test_stayOnRestoresMissingCredential_data() {
            return [
                { tag: "present", has: SecureStorage.StatusSuccess, set: SecureStorage.StatusSuccess, saves: 0, stay: [] },
                { tag: "missing", has: SecureStorage.StatusNotFound, set: SecureStorage.StatusSuccess, saves: 1, stay: [true] },
                { tag: "missing, save fails", has: SecureStorage.StatusNotFound, set: SecureStorage.StatusUnavailable, saves: 1, stay: [] },
            ]
        }
        function test_stayOnRestoresMissingCredential(data) {
            secureStorageStub.hasStatus = data.has
            secureStorageStub.setStatus = data.set
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p)
            privacyStoreStub.profilePasswordSet(true, "")

            compare(secureStorageStub.setCalls.length, data.saves)
            if (data.saves) {
                compare(secureStorageStub.setCalls[0].account, "uid_zero")
                compare(secureStorageStub.setCalls[0].credential, "dek:" + validPassword)
            }
            compare(privacyStoreStub.stayLoggedInCalls, data.stay)
            tryCompare(successCalls, "length", 1)
        }

        // The credential saved at creation is left alone when the choice was not offered
        function test_stayLoggedInUntouchedWhenNotOffered() {
            secureStorageStub.available = false
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p)
            privacyStoreStub.profilePasswordSet(true, "")

            compare(secureStorageStub.deleteCalls, [])
            compare(privacyStoreStub.stayLoggedInCalls, [])
            tryCompare(successCalls, "length", 1)
        }

        // An unverified removal keeps the preference consistent with the stored credential
        function test_stayOffKeepsPreferenceWhenRemovalFails_data() {
            return [
                { tag: "unavailable", status: SecureStorage.StatusUnavailable },
                { tag: "indeterminate", status: SecureStorage.StatusIndeterminate },
            ]
        }
        function test_stayOffKeepsPreferenceWhenRemovalFails(data) {
            secureStorageStub.deleteStatus = data.status
            const handler = createTemporaryObject(handlerComponent, root)
            const p = require(handler)
            submit(p, true, false)
            privacyStoreStub.profilePasswordSet(true, "")

            compare(privacyStoreStub.stayLoggedInCalls, [])
            tryCompare(successCalls, "length", 1)
        }
    }
}

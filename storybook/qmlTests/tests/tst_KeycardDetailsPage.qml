import QtQuick

import QtTest

import AppLayouts.Onboarding.pages

import utils

Item {
    id: root

    width: 800
    height: 700

    readonly property string profileKeyUid: "profile-key-uid-1"

    ListModel {
        id: loginAccounts

        ListElement {
            keyUid: "profile-key-uid-1"
            username: "Alice"
            colorId: 0
            thumbnailImage: ""
        }
    }

    ListModel {
        id: emptyLoginAccounts
    }

    Component {
        id: componentUnderTest

        KeycardDetailsPage {
            width: root.width
            height: root.height

            keycardState: Constants.keycard.state.ready
            keycardUid: "keycard-uid-1"
            keyUid: root.profileKeyUid
            keycardStatusAvailable: true
            remainingPinAttempts: 3
            remainingPukAttempts: 5
            availableSlots: 5
            cardMetadataName: "My Keycard"
            cardMetadataWalletAccountsJson: "[]"
            loginAccountsModel: loginAccounts
        }
    }

    SignalSpy {
        id: goBackSpy
        signalName: "goBackToLoginRequested"
    }

    TestCase {
        name: "KeycardDetailsPage_profileAlreadyExists"
        when: windowShown

        function test_showsProfileAlreadyExists() {
            const page = createTemporaryObject(componentUnderTest, root)
            verify(!!page)

            compare(findChild(page, "keycardDetailsTitle").text, "Profile already exists")
            compare(findChild(page, "keycardDetailsInfoMessage").text,
                    "Profile for key pair stored on Keycard already added to this device.")
        }

        function test_hidesLoginWithThisKeycard() {
            const page = createTemporaryObject(componentUnderTest, root)
            verify(!!page)

            const loginItem = findChild(page, "keycardDetailsLoginWithThisKeycard")
            verify(!!loginItem)
            verify(!loginItem.visible,
                   "login with this Keycard must be hidden when the profile is already on device")
        }

        function test_showsGoBackToLoginAndEmitsSignal() {
            const page = createTemporaryObject(componentUnderTest, root)
            verify(!!page)

            goBackSpy.target = page
            goBackSpy.clear()

            const goBack = findChild(page, "keycardDetailsGoBackToLogin")
            verify(!!goBack)
            verify(goBack.visible)

            mouseClick(goBack)
            compare(goBackSpy.count, 1)
        }

        function test_withoutMatchingProfileOffersLogin() {
            const page = createTemporaryObject(componentUnderTest, root, {
                                                   loginAccountsModel: emptyLoginAccounts
                                               })
            verify(!!page)

            compare(findChild(page, "keycardDetailsTitle").text, "Keycard stores key pair")
            verify(findChild(page, "keycardDetailsLoginWithThisKeycard").visible)
            verify(!findChild(page, "keycardDetailsGoBackToLogin").visible)
        }
    }

    TestCase {
        name: "KeycardDetailsPage_edgeStates"
        when: windowShown

        function test_onlyPinSet() {
            const page = createTemporaryObject(componentUnderTest, root, {
                                                   keyUid: "",
                                                   loginAccountsModel: emptyLoginAccounts
                                               })
            verify(!!page)

            compare(findChild(page, "keycardDetailsTitle").text, "Keycard stores only PIN")
            verify(findChild(page, "keycardDetailsImportNewKeypair").visible)
            verify(findChild(page, "keycardDetailsImportSeedPhrase").visible)
            verify(findChild(page, "keycardDetailsFactoryReset").visible)
            verify(!findChild(page, "keycardDetailsLoginWithThisKeycard").visible)
            verify(!findChild(page, "keycardDetailsGoBackToLogin").visible)
        }

        function test_noFreePairingSlots() {
            const page = createTemporaryObject(componentUnderTest, root, {
                                                   keycardState: Constants.keycard.state.noAvailablePairingSlots,
                                                   loginAccountsModel: emptyLoginAccounts
                                               })
            verify(!!page)

            compare(findChild(page, "keycardDetailsTitle").text, "No free pairing slots")
            compare(findChild(page, "keycardDetailsInfoMessage").text,
                    "You can’t operate with Keycard content right now, because Keycard has no free pairing slots. But you can use it with previously paired installations.")
            verify(findChild(page, "keycardDetailsFactoryReset").visible)
            verify(!findChild(page, "keycardDetailsImportNewKeypair").visible)
            verify(!findChild(page, "keycardDetailsLoginWithThisKeycard").visible)
        }

        function test_blockedPinOffersUnblockActions() {
            const page = createTemporaryObject(componentUnderTest, root, {
                                                   keycardState: Constants.keycard.state.blockedPIN,
                                                   remainingPinAttempts: 0,
                                                   loginAccountsModel: emptyLoginAccounts
                                               })
            verify(!!page)

            compare(findChild(page, "keycardDetailsTitle").text, "Keycard is blocked")
            verify(findChild(page, "keycardDetailsUnblockWithRecovery").visible)
            verify(findChild(page, "keycardDetailsUnblockWithPuk").visible)
            verify(!findChild(page, "keycardDetailsLoginWithThisKeycard").visible)
        }
    }
}

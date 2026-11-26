import QtQuick
import QtTest

import StatusQ

import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores as ProfileStores
import shared.stores
import mainui

Item {
    id: root

    width: 800
    height: 600

    // Read by SessionRoot as the context property Nim sets (true = a resume start)
    property bool skipOnboardingContextProperty: true

    // Like the JNI one: true once per process, then false
    property bool loginInterruptedPending: true
    property int consumeCalls: 0

    function consumeLoginInterrupted() {
        root.consumeCalls++
        const value = root.loginInterruptedPending
        root.loginInterruptedPending = false
        return value
    }

    Component {
        id: sessionComponent

        SessionRoot {
            anchors.fill: parent

            featureFlagsStore: AppStores.FeatureFlagsStore {}
            languageStore: ProfileStores.LanguageStore {}
            utilsStore: UtilsStore {}
            secureStorage: SecureStorage {}
            systemTrayIconAvailable: false
            portraitLayout: false
            allowsAutoLogin: (keyUid) => true
            relogin: () => true
            holdIntake: () => {}
            releaseIntake: () => {}
            keepBootLoginRecordCurrent: (record) => {}
            consumeLoginInterrupted: () => root.consumeLoginInterrupted()
        }
    }

    TestCase {
        name: "SessionRoot"
        when: windowShown

        function init() {
            root.skipOnboardingContextProperty = true
            root.loginInterruptedPending = true
            root.consumeCalls = 0
        }

        function test_theLoginInterruptedReasonIsConsumedAtCreationEvenOnAResumeStart() {
            const session = createTemporaryObject(sessionComponent, root)
            verify(!!session)
            compare(session.skipOnboarding, true)

            compare(root.consumeCalls, 1)
            compare(session.loginInterrupted, true)
        }

        function test_aReloginAfterAResumeStartDoesNotSeeTheReason() {
            // The resume start's session takes it; the relogin's session gets a fresh read.
            // The relogin session's value is what its login screen gets (see onLoaded)
            const resumed = createTemporaryObject(sessionComponent, root)
            compare(resumed.loginInterrupted, true)
            resumed.destroy()

            const relogin = createTemporaryObject(sessionComponent, root)
            compare(relogin.loginInterrupted, false)
            compare(root.consumeCalls, 2)
        }
    }
}

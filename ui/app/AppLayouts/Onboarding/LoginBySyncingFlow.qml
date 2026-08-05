pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums

OnboardingStackView {
    id: root

    required property var validateConnectionString
    required property int syncState

    signal syncProceedWithConnectionString(string connectionString)
    signal loginWithSeedphraseRequested
    signal finished

    initialItem: LoginBySyncingPage {
        validateConnectionString: root.validateConnectionString

        onSyncProceedWithConnectionString: (connectionString) => {
            root.syncProceedWithConnectionString(connectionString)
            root.push(syncProgressPage)
        }
    }

    Component {
        id: syncProgressPage

        SyncProgressPage {
            readonly property bool backAvailableHint:
                root.syncState === Onboarding.ProgressState.Failed

            syncState: root.syncState

            onLoginToAppRequested: root.finished()
            onRestartSyncRequested: root.pop()

            onLoginWithSeedphraseRequested: root.loginWithSeedphraseRequested()
        }
    }
}

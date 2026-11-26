import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.panels

import mainui

import Storybook

SplitView {
    Logs { id: logs }

    orientation: Qt.Vertical

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ModuleWarningStack {
            anchors.left: parent.left
            anchors.right: parent.right

            ZeroOnboardingBanner {
                Layout.fillWidth: true
                active: true

                onSetPasswordRequested: logs.logEvent("setPasswordRequested")
                onCreateOrLoginRequested: logs.logEvent("createOrLoginRequested")
            }

            TermsOfUseBanner {
                id: termsBanner

                Layout.fillWidth: true
                active: true

                onAcceptRequested: {
                    logs.logEvent("acceptRequested")
                    termsBanner.active = false
                }
                onTermsOfUseRequested: logs.logEvent("termsOfUseRequested")
                onPrivacyPolicyRequested: logs.logEvent("privacyPolicyRequested")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Button {
            text: "Show terms banner again"
            onClicked: termsBanner.active = true
        }
    }
}

// category: Panels
// status: good

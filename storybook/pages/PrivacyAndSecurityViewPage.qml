import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views

import Storybook

import utils

SplitView {

    Logs { id: logs }

    PrivacyAndSecurityView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        contentWidth: width

        privacySectionTitle: "Privacy"
        whitelistedDomainsModel: ["example1.com", "example2.com", "example3.com"]
        isStatusNewsViaRSSEnabled: true
        thirdpartyServicesEnabled: ctrlThirdpartyServicesEnabled.checked
        privacyModeFeatureEnabled: ctrlPrivacyMode.checked
        onOpenThirdpartyServicesInfoPopupRequested: {
            logs.logEvent("onLaunchThirdyPartyServicesInfoPopupRequested")
            ctrlThirdpartyServicesEnabled.checked = !ctrlThirdpartyServicesEnabled.checked
        }
        onOpenDiscussPageRequested: logs.logEvent("onOpenDiscussPageRequested")
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlPrivacyMode
                text: "Privacy Mode Feature Enabled"
                checked: true
            }

            Switch {
                id: ctrlThirdpartyServicesEnabled
                text: "Third Party Services Enabled"
                checked: true
            }
        }
    }
}

// category: Views
// status: good
// https://www.figma.com/design/idUoxN7OIW2Jpp3PMJ1Rl8/Settings----Desktop-Legacy?node-id=25914-21065&m=dev

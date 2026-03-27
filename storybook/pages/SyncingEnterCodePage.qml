import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Storybook

import mainui
import shared.views
import shared.stores as SharedStores
import shared.popups

import AppLayouts.stores as AppLayoutStores

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SyncingEnterCode {
            id: syncView
            width: 400
            anchors.horizontalCenter: parent.horizontalCenter
            validateConnectionString: (stringValue) => !Number.isNaN(parseInt(stringValue))

            onDisplayInstructions: {
                logs.logEvent("SyncingEnterCode::displayInstructions")
                instructionsPopup.createObject(root).open()
            }
            onProceed: (connectionString) => logs.logEvent("SyncingEnterCode::proceed", ["connectionString"], arguments)
        }

        Component {
            id: instructionsPopup
            GetSyncCodeInstructionsPopup {
                destroyOnClose: true
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText
    }
}

// category: Views

// "https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?type=design&node-id=1930-136137&mode=design&t=RSriG02fbmVOMAEx-0"
// "https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?type=design&node-id=13578-276069&mode=design&t=RSriG02fbmVOMAEx-0"

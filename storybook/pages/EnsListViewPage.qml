import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views

import Storybook

import utils

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: d

        property string preferredUsername: "alice.stateofus.eth"
    }

    ListModel {
        id: ensUsernamesModel

        ListElement { ensUsername: "alice.stateofus.eth"; isPending: false; chainId: 1 }
        ListElement { ensUsername: "bob.eth"; isPending: true; chainId: 1 }
        ListElement { ensUsername: "carol.stateofus.eth"; isPending: false; chainId: 1 }
    }

    Item {
        id: viewContainer

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        EnsListView {
            anchors.fill: parent
            profileContentWidth: Math.min(parent.width, 800)

            model: ensUsernamesModel
            preferredUsername: d.preferredUsername
            pubkey: "0xdeadbeef"
            icon: ""
            hasConfirmedEnsUsernames: ctrlHasConfirmed.checked

            onAddBtnClicked: logs.logEvent("EnsListView::addBtnClicked")
            onSelectEns: (username, chainId) => logs.logEvent("EnsListView::selectEns: " + username + " (chainId: " + chainId + ")")
            onPreferredUsernameSelected: (ensUsername) => {
                d.preferredUsername = ensUsername
                logs.logEvent("EnsListView::preferredUsernameSelected: " + ensUsername)
            }
        }

        // EnsListView opens its "Primary username" popup via Global.openPopup();
        // instantiate the requested component so the popup is visible in Storybook.
        Connections {
            target: Global

            function onOpenPopupRequested(popupComponent, params) {
                const popup = popupComponent.createObject(viewContainer, params)
                popup.open()
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 180

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlHasConfirmed
                text: "Has confirmed/pending ENS usernames"
                checked: true
            }

            Button {
                text: "Clear preferred username"

                onClicked: d.preferredUsername = ""
            }
        }
    }
}

// category: Views

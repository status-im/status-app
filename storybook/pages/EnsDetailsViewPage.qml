import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    readonly property string mockPubkey:
        "0x04c1a3b5d7e9f0112233445566778899aabbccddeeff00112233445566778899" +
        "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aa"

    function applyDetails() {
        let expirationTime = 0
        const nowSec = Math.floor(Date.now() / 1000)
        if (ctrlExpired.checked)
            expirationTime = nowSec - 24 * 60 * 60          // yesterday -> releasable
        else if (ctrlLocked.checked)
            expirationTime = nowSec + 30 * 24 * 60 * 60     // +30 days -> locked

        detailsView.setDetails(1 /*chainId*/, ctrlUsername.text, ctrlAddress.text,
                               root.mockPubkey, ctrlIsStatus.checked, expirationTime,
                               ctrlIsPreferred.checked)
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        EnsDetailsView {
            id: detailsView

            width: Math.min(parent.width - 48, 560)
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            username: ctrlUsername.text
            isLoading: ctrlLoading.checked

            onBackBtnClicked: logs.logEvent("EnsDetailsView::backBtnClicked")
            onReleaseUsernameRequested: (senderAddress) =>
                logs.logEvent("EnsDetailsView::releaseUsernameRequested: " + senderAddress)
            onRemoveEnsUsernameRequested: (chainId, username) =>
                logs.logEvent("EnsDetailsView::removeEnsUsernameRequested: chainId=" + chainId + ", username=" + username)

            Component.onCompleted: root.applyDetails()
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 320

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Label { text: "Username:" }
                TextField {
                    id: ctrlUsername
                    text: "michal.stateofus.eth"
                }
            }

            RowLayout {
                Label { text: "Address:" }
                TextField {
                    id: ctrlAddress
                    Layout.preferredWidth: 360
                    text: "0x1234567890abcdef1234567890abcdef12345678"
                }
            }

            Switch {
                id: ctrlLoading
                text: "Loading"
            }

            Switch {
                id: ctrlIsStatus
                text: "Is Status name (shows Release button)"
                checked: true
            }

            Switch {
                id: ctrlIsPreferred
                text: "Is preferred username (blocks release)"
            }

            RowLayout {
                Label { text: "Expiration:" }

                RadioButton {
                    id: ctrlExpired
                    text: "Expired (releasable)"
                    checked: true
                }
                RadioButton {
                    id: ctrlLocked
                    text: "Locked (future)"
                }
                RadioButton {
                    id: ctrlNoExpiration
                    text: "None (0)"
                }
            }

            Button {
                text: "Apply details"

                onClicked: root.applyDetails()
            }
        }
    }
}

// category: Views

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import Storybook

import AppLayouts.Profile.views

SplitView {
    id: root

    orientation: Qt.Horizontal

    // Shaped like wakuext_getTrafficReport, with invented numbers of a 72 min session.
    QtObject {
        id: fixture

        function row(sentMb, receivedMb, rest) {
            return Object.assign({bytesSent: Math.round(sentMb * 1024 * 1024),
                                  bytesReceived: Math.round(receivedMb * 1024 * 1024)}, rest)
        }

        readonly property var snapshot: ({
            since: "2026-10-13T13:00:00.663257+04:00",
            until: "2026-10-13T14:12:00.715962+04:00",
            totals: row(18.4, 96.2),
            protocols: [
                row(12.6, 60.5, {protocol: "/vac/waku/relay/2.0.0"}),
                row(0.4, 24.9, {protocol: "/vac/waku/store-query/3.0.0"}),
                row(0.1, 7.4, {protocol: "/vac/waku/filter-push/2.0.0-beta1"}),
                row(3.4, 0.1, {protocol: "/vac/waku/lightpush/2.0.0-beta1"}),
                row(0.5, 1.3, {protocol: "/vac/waku/peer-exchange/2.0.0-alpha1"}),
                row(0.5, 0.6, {protocol: "/rendezvous/1.0.0"}),
                row(0.3, 0.6, {protocol: "/ipfs/id/1.0.0"}),
                row(0.3, 0.3, {protocol: "/vac/waku/filter-subscribe/2.0.0-beta1"}),
                row(0.2, 0.3, {protocol: "/ipfs/ping/1.0.0"}),
                row(0.1, 0.2, {protocol: ""})
            ],
            peers: [
                row(4.1, 39.4, {peer: "16Uiu2HAmAR24Mbb6VuzoyUiGx42UenDkshENVDj4qnmmbabLvo31"}),
                row(0.9, 24.3, {peer: "16Uiu2HAm8mUZ18tBWPXDQsaF7PbCKYA35z7WB2xNZH2EVq1qS8LJ"}),
                row(3.2, 7.1, {peer: "16Uiu2HAmNTpGnyZ8W1BK2sXEmgSCNWiyDKgRU3NBR2DXST2HzxRU"}),
                row(2.4, 6.0, {peer: "16Uiu2HAkvWiyFsgRhuJEb9JfjYxEkoHLgnUQmr1N5mKWnYjxYRVm"}),
                row(7.8, 19.4, {peer: "16Uiu2HAmGwcE8v7gmJNEWFtZtojYpPMTHy2jBLL6xRk33qgDxFWX"})
            ]
        })
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.baseColor2

        // As wide as the HTTP statistics popup.
        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: Math.min(parent.height - 32, 760)
            radius: Theme.radius
            color: Theme.palette.statusModal.backgroundColor

            WakuTrafficDashboard {
                anchors.fill: parent
                anchors.margins: 16
                stats: emptyCheckBox.checked ? null : fixture.snapshot
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            CheckBox {
                id: emptyCheckBox
                text: "No report"
            }
        }
    }
}

// category: Views
// status: good
